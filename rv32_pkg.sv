`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 03:22:39 PM
// Design Name: 
// Module Name: rv32_pkg
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
/////////////////////////////////////////////////////////////////////////////////
package rv32_pkg;

typedef enum logic [3:0]{
ALU_ADD = 4'b0000, 
ALU_SUB = 4'b1000,
ALU_AND = 4'b0111,
ALU_OR = 4'b0110,
ALU_SLT = 4'b0010
} aluop_t;

typedef struct packed{
logic [31:0] pc;
logic [31:0] instr;
} ifid_t;

typedef struct packed{
logic [31:0] pc_plus4, rs1_data, rs2_data, imm;
logic [4:0] rs1, rs2, rd;
logic       mem_write, mem_read, alu_src, mem_to_reg, reg_write, branch, jal, jalr;
logic [3:0] alu_ctrl; 
logic [6:0] opcode;
} idex_t

typedef struct packed{
logic       mem_write, mem_read, mem_to_reg, reg_write, jal, jalr;
logic [31:0] alu_result, pc_plus4, rs2_data;
logic [31:0] rd;
} exmem_t;

typedef struct packed{
logic reg_write, jal, jalr, mem_to_reg;
logic [31:0] alu_result, pc_plus4, mem_rdata;
logic [31:0] rd;
} memwb_t;

 // Quick field helpers
  function automatic logic [6:0]  get_opcode(input logic [31:0] instr); 
  return instr[6:0];   
  endfunction
  
  function automatic logic [4:0]  get_rd(input logic [31:0] instr); 
  return instr[11:7];  
  endfunction
  
  function automatic logic [2:0]  get_func3 (input logic [31:0] instr);
  return instr[14:12]; 
  endfunction
   
  function automatic logic [4:0]  get_rs1 (input logic [31:0] instr);
  return instr[19:15]; 
  endfunction
  
  function automatic logic [4:0]  get_rs2 (input logic [31:0] instr); 
  return instr[24:20]; 
  endfunction
  
  function automatic logic [6:0]  get_func7 (input logic [31:0] instr); 
  return instr[31:25]; 
  endfunction

function automatic logic [31:0] imm_i(input logic [31:0] instr);
return {{20{instr[31]}}, instr[31:20]};
endfunction

function automatic logic [31:0] imm_s(input logic [31:0] instr);
return {{20{instr[31]}}, instr[31:25], instr[11:7]};
endfunction

function automatic logic [31:0] imm_b(input logic [31:0] instr);
return {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
endfunction

function automatic logic [31:0] imm_j(input logic [31:0] instr);
return {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
endfunction

 function automatic logic [31:0] imm_u(input logic [31:0] instr);
 return {instr[31:12], 12'b0};
 endfunction
 
endpackage






