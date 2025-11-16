`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 03:44:54 PM
// Design Name: 
// Module Name: control_unit
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
module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] func3,
    input  logic [6:0] func7,

    output logic       alu_src,
    output logic       mem_write,
    output logic       mem_read,
    output logic       mem_to_reg,
    output logic       branch,
    output logic       jal,
    output logic       jalr,
    output logic       reg_write,
    output logic [3:0] alu_ctrl
);
    // RISC-V opcodes
    localparam OPCODE_OP      = 7'b0110011; // R-type
    localparam OPCODE_OP_IMM  = 7'b0010011; // I-type ALU
    localparam OPCODE_LOAD    = 7'b0000011; // LW
    localparam OPCODE_STORE   = 7'b0100011; // SW
    localparam OPCODE_BRANCH  = 7'b1100011; // BEQ
    localparam OPCODE_JAL     = 7'b1101111; // JAL
    localparam OPCODE_JALR    = 7'b1100111; // JALR
    localparam OPCODE_LUI     = 7'b0110111; // LUI
    localparam OPCODE_AUIPC   = 7'b0010111; // AUIPC

    // ALU op encodings (must match rv32_pkg.sv)
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b1000;
    localparam ALU_AND = 4'b0111;
    localparam ALU_OR  = 4'b0110;
    localparam ALU_SLT = 4'b0010;

    always_comb begin
        // defaults
        alu_src   = 1'b0;
        mem_write = 1'b0;
        mem_read  = 1'b0;
        mem_to_reg= 1'b0;
        branch    = 1'b0;
        jal       = 1'b0;
        jalr      = 1'b0;
        reg_write = 1'b0;
        alu_ctrl  = ALU_ADD;

        unique case (opcode)
            // R-type: ADD, SUB, AND, OR, SLT
            OPCODE_OP: begin
                alu_src   = 1'b0;
                reg_write = 1'b1;
                mem_to_reg= 1'b0;
                mem_write = 1'b0;
                mem_read  = 1'b0;
                branch    = 1'b0;
                jal       = 1'b0;
                jalr      = 1'b0;

                unique case ({func7, func3})
                    {7'b0000000, 3'b000}: alu_ctrl = ALU_ADD; // ADD
                    {7'b0100000, 3'b000}: alu_ctrl = ALU_SUB; // SUB
                    {7'b0000000, 3'b111}: alu_ctrl = ALU_AND; // AND
                    {7'b0000000, 3'b110}: alu_ctrl = ALU_OR;  // OR
                    {7'b0000000, 3'b010}: alu_ctrl = ALU_SLT; // SLT
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            // I-type ALU: ADDI, ANDI, ORI
            OPCODE_OP_IMM: begin
                alu_src   = 1'b1;  // use imm
                reg_write = 1'b1;
                mem_to_reg= 1'b0;
                mem_write = 1'b0;
                mem_read  = 1'b0;

                unique case (func3)
                    3'b000: alu_ctrl = ALU_ADD; // ADDI
                    3'b111: alu_ctrl = ALU_AND; // ANDI
                    3'b110: alu_ctrl = ALU_OR;  // ORI
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            // LOAD: LW
            OPCODE_LOAD: begin
                alu_src   = 1'b1;  // base + imm
                reg_write = 1'b1;
                mem_read  = 1'b1;
                mem_to_reg= 1'b1;  // from memory
            end

            // STORE: SW
            OPCODE_STORE: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                reg_write = 1'b0;
            end

            // BRANCH: BEQ
            OPCODE_BRANCH: begin
                branch    = 1'b1;
                alu_ctrl  = ALU_SUB; // compare via SUB
            end

            // JAL
            OPCODE_JAL: begin
                jal       = 1'b1;
                reg_write = 1'b1;  // write PC+4 to rd
            end

            // JALR
            OPCODE_JALR: begin
                jalr      = 1'b1;
                reg_write = 1'b1;
                alu_src   = 1'b1; // rs1 + imm used for PC calc (in EX)
            end

            // LUI
            OPCODE_LUI: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_ctrl  = ALU_ADD; // typically pass imm in EX or handle separately
            end

            // AUIPC
            OPCODE_AUIPC: begin
                reg_write = 1'b1;
                alu_src = 1'b1;
                alu_ctrl  = ALU_ADD;
            end

            default: begin
                // everything stays 0
            end
        endcase
    end

endmodule
