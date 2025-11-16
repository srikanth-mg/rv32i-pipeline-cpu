`include "rv32_pkg.sv"

module rv32_top (
    input  logic clk,
    input  logic rst_n
);
    import rv32_pkg::*;

    // ===== IF =====
    logic [31:0] pc_q, pc_d, instr_if;
    logic [31:0] pc_plus4_if;

    // PC register (sync, active-low reset)
    always_ff @(posedge clk) begin
        if (!rst_n)
            pc_q <= 32'd0;
        else
            pc_q <= pc_d;
    end

    // Instruction memory (combinational read)
    instr_mem IMEM1 (
        .addr (pc_q[31:2]),
        .instr(instr_if)
    );

    // IF/ID pipeline register
    ifid_t ifid_q, ifid_d;

    // IF/ID next-state logic
    always_comb begin
        ifid_d = ifid_q;
        ifid_d.pc    = pc_plus4_if;  // PC+4 of current IF stage
        ifid_d.instr = instr_if;
    end

    always_ff @(posedge clk) begin
        if (!rst_n)
            ifid_q <= '{default:'0};
        else
            ifid_q <= ifid_d;
    end

    // ===== DECODE (ID) =====
// basic fields from instruction
logic [6:0] opcode;
logic [2:0] func3;
logic [6:0] func7;
logic [4:0] rs1, rs2, rd;
localparam logic [6:0] OPCODE_LUI = 7'b0110111;

always_comb begin
  opcode = get_opcode(ifid_q.instr);
  func3  = get_func3(ifid_q.instr);
  func7  = get_func7(ifid_q.instr);
  rs1    = get_rs1(ifid_q.instr);
  rs2    = get_rs2(ifid_q.instr);
  rd     = get_rd(ifid_q.instr);
  
  if(opcode == OPCODE_LUI)
  rs1 = 5'd0;
  
  end

// control signals
logic       alu_src, mem_write, mem_read, mem_to_reg;
logic       branch, jal, jalr, reg_write;
logic [3:0] alu_ctrl;

control_unit C1 (
  .opcode    (opcode),
  .func3     (func3),
  .func7     (func7),
  .alu_src   (alu_src),
  .mem_write (mem_write),
  .mem_read  (mem_read),
  .mem_to_reg(mem_to_reg),
  .branch    (branch),
  .jal       (jal),
  .jalr      (jalr),
  .reg_write (reg_write),
  .alu_ctrl  (alu_ctrl)
);

// register file hookup
logic [31:0] rs1_data, rs2_data, wb_data;
logic [4:0]  wb_rd;
logic        wb_we;

regfile RF1 (
  .clk (clk),
  .ra1 (rs1),
  .ra2 (rs2),
  .wa  (wb_rd),
  .we  (wb_we),
  .wd  (wb_data),
  .rd1 (rs1_data),
  .rd2 (rs2_data)
);

// immediate decode
logic [31:0] imm_id;

always_comb begin
  unique case (opcode)
    7'b0010011, // OP-IMM: ADDI/ANDI/ORI
    7'b0000011, // LOAD: LW
    7'b1100111: // JALR
      imm_id = imm_i(ifid_q.instr);

    7'b0100011: // STORE: SW
      imm_id = imm_s(ifid_q.instr);

    7'b1100011: // BRANCH: BEQ
      imm_id = imm_b(ifid_q.instr);

    7'b1101111: // JAL
      imm_id = imm_j(ifid_q.instr);

    7'b0110111, // LUI
    7'b0010111: // AUIPC
      imm_id = imm_u(ifid_q.instr);

    default:
      imm_id = 32'd0;
  endcase
end

// ===== ID/EX PIPELINE REG =====
idex_t idex_q, idex_d;

always_ff @(posedge clk) begin
  if (!rst_n)
    idex_q <= '{default:'0};
  else
    idex_q <= idex_d;
end

always_comb begin
  // IMPORTANT: give everything a known base value
  idex_d = '{default:'0};

  idex_d.pc_plus4   = ifid_q.pc;
  idex_d.rs1_data   = rs1_data;
  idex_d.rs2_data   = rs2_data;
  idex_d.imm        = imm_id;
  idex_d.rs1        = rs1;
  idex_d.rs2        = rs2;
  idex_d.rd         = rd;
  
  idex_d.opcode = opcode;
  idex_d.alu_src    = alu_src;
  idex_d.mem_read   = mem_read;
  idex_d.mem_write  = mem_write;
  idex_d.mem_to_reg = mem_to_reg;
  idex_d.reg_write  = reg_write;
  idex_d.branch     = branch;
  idex_d.jal        = jal;
  idex_d.jalr       = jalr;
  idex_d.alu_ctrl   = alu_ctrl;
end

    // ===== EX =====
    logic [31:0] alu_in_b;
    logic [31:0] alu_out;
    
    logic [1:0]  fwd_a_sel, fwd_b_sel;
    logic [31:0] ex_src_a, ex_src_b_raw;
    
    // ===== Forwarding + ALU operand selection (inline forwarding unit) =====
always_comb begin
    // defaults
    fwd_a_sel    = 2'b00;
    fwd_b_sel    = 2'b00;
    ex_src_a     = idex_q.rs1_data;
    ex_src_b_raw = idex_q.rs2_data;

    // ----- Forward A (rs1) -----
    if (exmem_q.reg_write && (exmem_q.rd != 0) && (exmem_q.rd == idex_q.rs1))
        fwd_a_sel = 2'b10;       // EX/MEM
    else if (memwb_q.reg_write && (memwb_q.rd != 0) && (memwb_q.rd == idex_q.rs1))
        fwd_a_sel = 2'b01;       // MEM/WB

    // ----- Forward B (rs2) -----
    if (exmem_q.reg_write && (exmem_q.rd != 0) && (exmem_q.rd == idex_q.rs2))
        fwd_b_sel = 2'b10;
    else if (memwb_q.reg_write && (memwb_q.rd != 0) && (memwb_q.rd == idex_q.rs2))
        fwd_b_sel = 2'b01;

    // Apply the selects for A
    unique case (fwd_a_sel)
        2'b10: ex_src_a     = exmem_q.alu_result; // from EX/MEM
        2'b01: ex_src_a     = wb_data;            // from MEM/WB (final WB value)
        default: ex_src_a   = idex_q.rs1_data;  // 2'b00 → keep ID/EX
    endcase

    // Apply the selects for B (raw rs2)
    unique case (fwd_b_sel)
        2'b10: ex_src_b_raw = exmem_q.alu_result;
        2'b01: ex_src_b_raw = wb_data;
        default:  ex_src_b_raw = idex_q.rs2_data;
    endcase

    // ALU B input: forwarded rs2 or immediate
    alu_in_b = idex_q.alu_src ? idex_q.imm : ex_src_b_raw;
end

    alu A1 (
        .rs1_data (ex_src_a),
        .rs2_data (alu_in_b),
        .alu_ctrl (idex_q.alu_ctrl),
        .rd       (alu_out)
    );

    // Branch/jump targets
    logic        beq_taken     = idex_q.branch && (idex_q.rs1_data == idex_q.rs2_data);
    logic [31:0] branch_target = (idex_q.pc_plus4 - 32'd4) + idex_q.imm; // base PC is PC of instr
    logic [31:0] jal_target    = (idex_q.pc_plus4 - 32'd4) + idex_q.imm;
    logic [31:0] jalr_target   = (idex_q.rs1_data + idex_q.imm) & ~32'd1;
   
    // ===== EX/MEM =====
    exmem_t exmem_q, exmem_d;

    always_ff @(posedge clk) begin
        if (!rst_n)
            exmem_q <= '{default:'0};
        else
            exmem_q <= exmem_d;
    end

    always_comb begin
        exmem_d ='{default:'0};
        exmem_d.alu_result   = alu_out;           // field names must match your rv32_pkg
        exmem_d.rs2_data     = idex_q.rs2_data;
        exmem_d.rd           = idex_q.rd;
        exmem_d.mem_read     = idex_q.mem_read;
        exmem_d.mem_write    = idex_q.mem_write;
        exmem_d.mem_to_reg   = idex_q.mem_to_reg;
        exmem_d.reg_write    = idex_q.reg_write;
        exmem_d.pc_plus4     = idex_q.pc_plus4;
        exmem_d.jal          = idex_q.jal;
        exmem_d.jalr         = idex_q.jalr;
    end

    // ===== MEM =====
    logic [31:0] mem_rdata;

    data_mem DM1 (
        .clk (clk),
        .addr(exmem_q.alu_result[31:2]),
        .we  (exmem_q.mem_write),
        .wd  (exmem_q.rs2_data),
        .rd  (mem_rdata)
    );

    // ===== MEM/WB =====
    memwb_t memwb_q, memwb_d;

    always_ff @(posedge clk) begin
        if (!rst_n)
            memwb_q <= '{default:'0};
        else
            memwb_q <= memwb_d;
    end

    always_comb begin
        memwb_d.alu_result   = exmem_q.alu_result;
        memwb_d.mem_rdata    = mem_rdata;
        memwb_d.rd           = exmem_q.rd;
        memwb_d.mem_to_reg   = exmem_q.mem_to_reg;
        memwb_d.reg_write    = exmem_q.reg_write;
        memwb_d.pc_plus4     = exmem_q.pc_plus4;
        memwb_d.jal          = exmem_q.jal;
        memwb_d.jalr         = exmem_q.jalr;
    end
    
    // ===== WB =====
    logic [31:0] wb_src;

    assign wb_src  = memwb_q.mem_to_reg ? memwb_q.mem_rdata : memwb_q.alu_result;
    assign wb_data = (memwb_q.jal || memwb_q.jalr) ? memwb_q.pc_plus4 : wb_src;
    assign wb_rd   = memwb_q.rd;
    assign wb_we   = memwb_q.reg_write;
    
    always_ff @(posedge clk) begin
    if (rst_n && wb_we && (wb_rd != 5'd0)) begin
    $display("[%0t] WB: x%0d <= 0x%08x",
             $time, wb_rd, wb_data);
  end
end

    // ===== PC + next-PC logic (put at bottom so signals are declared) =====
    always_comb begin
        // default: sequential PC
        pc_plus4_if = pc_q + 32'd4;

        if      (idex_q.jal)  pc_d = jal_target;
        else if (idex_q.jalr) pc_d = jalr_target;
        else if (beq_taken)   pc_d = branch_target;
        else                  pc_d = pc_plus4_if;
    end

endmodule
