`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 09:49:44 PM
// Design Name: 
// Module Name: data_mem
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
module data_mem(
  input  logic        clk,
  input  logic [31:2] addr,    // word aligned
  input  logic        we,
  input  logic [31:0] wd,
  output logic [31:0] rd
);
  logic [31:0] mem [0:255];

  always_ff @(posedge clk) begin
    if (we) mem[addr] <= wd; // for SW operation
  end
  assign rd = mem[addr];  //for LW operation
endmodule
