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


module control_unit(
 input logic [6:0] opcode,
 input logic [6:0] func7,
 input logic [2:0] func3,
 output logic alu_src, mem_write, mem_read, mem_to_reg, reg_write, branch, jal ,jalr, 
 output rv32_pkg::aluop_t alu_ctrl
    );
    
  import rv32_pkg::*;
    
  always_comb begin
  alu_src = 0; mem_write = 0; mem_read = 0; mem_to_reg = 0; reg_write =0; branch = 0; jal = 0; jalr =0;
  alu_ctrl = ALU_ADD;
    
    unique case (opcode)
    7'b0110011 : begin 
    reg_write = 1;
    if ((func3 == 3'b000 ) && (func7 == 7'b0100000)) 
    alu_ctrl = ALU_SUB;
    else if (func3 == 3'b000) alu_ctrl = ALU_SUB;
    else if (func3==3'b111) alu_ctrl=ALU_AND;
    else if (func3==3'b110) alu_ctrl=ALU_OR;
    else if (func3==3'b010) alu_ctrl=ALU_SLT;  
    end
    7'b0010011: begin alu_src=1; reg_write=1; alu_ctrl=ALU_ADD; end // ADDI
    7'b0000011: begin alu_src=1; mem_read=1; mem_to_reg=1; reg_write=1; end // LW
    7'b0100011: begin alu_src=1; mem_write=1; end // SW
    7'b1100011: begin branch=1; end // BEQ
    7'b1101111: begin jal=1; reg_write=1; end // JAL
    7'b1100111: begin jalr=1; alu_src=1; reg_write=1; end // JALR
    default: ;
    endcase
    end
endmodule
