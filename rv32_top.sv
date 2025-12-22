`include "rv32_pkg.sv"

module rv32_top (
    input  logic clk,
    input  logic rst_n
);

    import rv32_pkg::*;

    // ===== IF/ID =====
    ifid_t ifid_q, ifid_d;

    // Program counter
    logic [31:0] pc_q, pc_d;
    logic [31:0] pc_plus4_if;

    always_ff @(posedge clk) begin
        if (!rst_n) pc_q <= 32'd0;
        else        pc_q <= pc_d;
    end

    // Instruction fetch
    logic [31:0] instr_if;

    instr_mem IMEM1 (
        .addr  (pc_q[31:2]),
        .instr (instr_if)
    );

    // IF/ID pipeline register update
    // (stalling handled by gating ifid_d updates in always_comb)
    always_ff @(posedge clk) begin
        if (!rst_n)
            ifid_q <= '{default:'0};
        else
            ifid_q <= ifid_d;
    end

    // ===== ID =====
    // Decode fields (combinational)
    logic [6:0] opcode;
    logic [2:0] func3;
    logic [6:0] func7;
    logic [4:0] id_rs1;
    logic [4:0] id_rs2;
    logic [4:0] id_rd;

    always_comb begin
        opcode = get_opcode(ifid_q.instr);
        func3  = get_func3(ifid_q.instr);
        func7  = get_func7(ifid_q.instr);
        id_rs1 = get_rs1(ifid_q.instr);
        id_rs2 = get_rs2(ifid_q.instr);
        id_rd  = get_rd (ifid_q.instr);
    end

    // Control signals from control_unit
    logic       alu_src;
    logic       mem_write;
    logic       mem_read;
    logic       mem_to_reg;
    logic       branch;
    logic       jal;
    logic       jalr;
    logic       reg_write;
    logic [3:0] alu_ctrl;

    control_unit C1 (
        .opcode     (opcode),
        .func3      (func3),
        .func7      (func7),
        .alu_src    (alu_src),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .mem_to_reg (mem_to_reg),
        .branch     (branch),
        .jal        (jal),
        .jalr       (jalr),
        .reg_write  (reg_write),
        .alu_ctrl   (alu_ctrl)
    );

    // Register file / WB hookup
    logic [31:0] rs1_data, rs2_data, wb_data;
    logic [4:0]  wb_rd;
    logic        wb_we;

    regfile RF1 (
        .clk (clk),
        .ra1 (id_rs1),
        .ra2 (id_rs2),
        .wa  (wb_rd),
        .we  (wb_we),
        .wd  (wb_data),
        .rd1 (rs1_data),
        .rd2 (rs2_data)
    );

    // ID-stage WB bypass (fixes RF write/read same-edge visibility)
    logic [31:0] id_rs1_data_byp, id_rs2_data_byp;
    assign id_rs1_data_byp = (wb_we && (wb_rd != 5'd0) && (wb_rd == id_rs1)) ? wb_data : rs1_data;
    assign id_rs2_data_byp = (wb_we && (wb_rd != 5'd0) && (wb_rd == id_rs2)) ? wb_data : rs2_data;

    // Immediate select
    logic [31:0] imm_id;
    always_comb begin
        unique case (opcode)
            7'b0010011, // ADDI
            7'b0000011, // LW
            7'b1100111: // JALR
                imm_id = imm_i(ifid_q.instr);
            7'b0100011: // SW
                imm_id = imm_s(ifid_q.instr);
            7'b1100011: // BEQ
                imm_id = imm_b(ifid_q.instr);
            7'b1101111: // JAL
                imm_id = imm_j(ifid_q.instr);
            default:
                imm_id = 32'd0;
        endcase
    end

    // ===== ID/EX =====
    idex_t idex_q, idex_d;

    // Hazard detection (load-use) stall
    logic hazard_stall;

    hazard_unit HU (
        .ex_memRead (idex_q.mem_read),
        .ex_rd      (idex_q.rd),
        .id_rs1     (id_rs1),
        .id_rs2     (id_rs2),
        .stall      (hazard_stall)
    );

    // ID/EX pipeline register update
    always_ff @(posedge clk) begin
        if (!rst_n)
            idex_q <= '{default:'0};
        else
            idex_q <= idex_d;
    end

    // ID/EX next-state logic
    always_comb begin
        idex_d = '{default:'0};

        // default propagate
        idex_d.pc_plus4   = ifid_q.pc;          // (your ifid pc field holds pc+4 or pc? keep consistent)
        idex_d.rs1_data   = id_rs1_data_byp;    
        idex_d.rs2_data   = id_rs2_data_byp;    
        idex_d.imm        = imm_id;
        idex_d.rs1        = id_rs1;
        idex_d.rs2        = id_rs2;
        idex_d.rd         = id_rd;

        // control signals
        idex_d.alu_src    = alu_src;
        idex_d.mem_read   = mem_read;
        idex_d.mem_write  = mem_write;
        idex_d.mem_to_reg = mem_to_reg;
        idex_d.reg_write  = reg_write;
        idex_d.branch     = branch;
        idex_d.jal        = jal;
        idex_d.jalr       = jalr;
        idex_d.alu_ctrl   = alu_ctrl;

        // On hazard stall, insert bubble into EX (NOP)
        if (hazard_stall) begin
            idex_d.alu_src    = 1'b0;
            idex_d.mem_read   = 1'b0;
            idex_d.mem_write  = 1'b0;
            idex_d.mem_to_reg = 1'b0;
            idex_d.reg_write  = 1'b0;
            idex_d.branch     = 1'b0;
            idex_d.jal        = 1'b0;
            idex_d.jalr       = 1'b0;
            idex_d.alu_ctrl   = 4'b0000;
            idex_d.rd         = 5'd0;
            idex_d.rs1        = 5'd0;
            idex_d.rs2        = 5'd0;
        end
    end

    // ===== EX =====
    // Forwarding in EX stage (EX/MEM and MEM/WB -> EX)
    logic [1:0] forward_a, forward_b;
    logic [31:0] ex_op_a, ex_op_b_raw, ex_op_b;
    logic [31:0] alu_out;

    exmem_t exmem_q, exmem_d;
    memwb_t memwb_q, memwb_d;

    forward_unit FU (
        .exmem_reg_write (exmem_q.reg_write),
        .exmem_rd        (exmem_q.rd),
        .memwb_reg_write (memwb_q.reg_write),
        .memwb_rd        (memwb_q.rd),
        .idex_rs1        (idex_q.rs1),
        .idex_rs2        (idex_q.rs2),
        .forward_a       (forward_a),
        .forward_b       (forward_b)
    );

    // Select forwarded operands for ALU and comparisons
    always_comb begin
        ex_op_a     = idex_q.rs1_data;
        ex_op_b_raw = idex_q.rs2_data;

        unique case (forward_a)
            2'b10: ex_op_a = exmem_q.alu_result; // EX/MEM
            2'b01: ex_op_a = wb_data;            // MEM/WB
            default: ;
        endcase

        unique case (forward_b)
            2'b10: ex_op_b_raw = exmem_q.alu_result;
            2'b01: ex_op_b_raw = wb_data;
            default: ;
        endcase
    end

    // ALU second operand mux (imm vs forwarded rs2)
    assign ex_op_b = (idex_q.alu_src) ? idex_q.imm : ex_op_b_raw;

    alu A1 (
        .rs1_data (ex_op_a),
        .rs2_data (ex_op_b),
        .alu_ctrl (idex_q.alu_ctrl),
        .rd       (alu_out)
    );

    // Branch/jump targets (use forwarded rs1 for jalr; forwarded rs1/rs2 for beq)
    logic        beq_taken;
    logic [31:0] branch_target, jal_target, jalr_target;

    assign beq_taken     = idex_q.branch && (ex_op_a == ex_op_b_raw);
    assign branch_target = (idex_q.pc_plus4 - 32'd4) + idex_q.imm;
    assign jal_target    = (idex_q.pc_plus4 - 32'd4) + idex_q.imm;
    assign jalr_target   = (ex_op_a + idex_q.imm) & ~32'd1;

    // ===== EX/MEM =====
    always_ff @(posedge clk) begin
        if (!rst_n)
            exmem_q <= '{default:'0};
        else
            exmem_q <= exmem_d;
    end

    always_comb begin
        exmem_d = '{default:'0};

        exmem_d.alu_result   = alu_out;
        exmem_d.rs2_data     = ex_op_b_raw;     // ✅ store data forwarded
        exmem_d.rd           = idex_q.rd;

        exmem_d.mem_read     = idex_q.mem_read;
        exmem_d.mem_write    = idex_q.mem_write;
        exmem_d.mem_to_reg   = idex_q.mem_to_reg;
        exmem_d.reg_write    = idex_q.reg_write;


        exmem_d.pc_plus4     = idex_q.pc_plus4;
    end

    // ===== MEM =====
    logic [31:0] mem_rdata;

data_mem DM1 (
    .clk (clk),
    .addr(exmem_q.alu_result[31:2]),
    .wd  (exmem_q.rs2_data),     // store data
    .we  (exmem_q.mem_write),    // write enable
    .rd  (mem_rdata)             // read data
);


    // ===== MEM/WB =====
    always_ff @(posedge clk) begin
        if (!rst_n)
            memwb_q <= '{default:'0};
        else
            memwb_q <= memwb_d;
    end

    always_comb begin
        memwb_d = '{default:'0};

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

    // ===== PC + next-PC logic =====
    always_comb begin
        // default sequential
        pc_plus4_if = pc_q + 32'd4;

        if      (idex_q.jal)  pc_d = jal_target;
        else if (idex_q.jalr) pc_d = jalr_target;
        else if (beq_taken)   pc_d = branch_target;
        else                  pc_d = pc_plus4_if;

        // IF/ID defaults
        ifid_d = ifid_q;

        // Freeze PC + IF/ID on hazard stall
        if (hazard_stall) begin
            pc_d       = pc_q;        // freeze PC
            ifid_d     = ifid_q;      // freeze IF/ID
        end else begin
            // normal IF stage update
            ifid_d.pc    = pc_plus4_if;
            ifid_d.instr = instr_if;
        end
    end

endmodule
