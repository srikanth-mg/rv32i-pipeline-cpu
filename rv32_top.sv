`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 04:00:00 PM
// Design Name: 
// Module Name: rv32_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

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
        ifid_d.pc    = pc_plus4_if;  // PC+4 of current IF stage
        ifid_d.instr = instr_if;
    end

    always_ff @(posedge clk) begin
        if (!rst_n)
            ifid_q <= '{default:'0};
        else
            ifid_q <= ifid_d;
    end

    // ===== ID =====
    // Decode fields
    logic [6:0] opcode = get_opcode(ifid_q.instr);
    logic [2:0] func3  = get_func3(ifid_q.instr);
    logic [6:0] func7  = get_func7(ifid_q.instr);
    logic [4:0] rs1    = get_rs1(ifid_q.instr);
    logic [4:0] rs2    = get_rs2(ifid_q.instr);
    logic [4:0] rd     = get_rd(ifid_q.instr);

    // Control signals
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
        .alu_ctrl  (alu_ctrl)   // don't forget this!
    );

    // Register file / WB hookup
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
            7'b0110111, // LUI (unused)
            7'b0010111: // AUIPC (unused)
                imm_id = imm_u(ifid_q.instr);
            default:
                imm_id = 32'd0;
        endcase
    end

    // ===== ID/EX =====
    idex_t idex_q, idex_d;

    always_ff @(posedge clk) begin
        if (!rst_n)
            idex_q <= '{default:'0};
        else
            idex_q <= idex_d;
    end

    always_comb begin
        idex_d.pc_plus4   = ifid_q.pc;
        idex_d.rs1_data   = rs1_data;
        idex_d.rs2_data   = rs2_data;
        idex_d.imm        = imm_id;
        idex_d.rs1        = rs1;
        idex_d.rs2        = rs2;
        idex_d.rd         = rd;
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
    logic [31:0] alu_in_b = idex_q.alu_src ? idex_q.imm : idex_q.rs2_data;
    logic [31:0] alu_out;

    alu A1 (
        .rs1_data (idex_q.rs1_data),
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
