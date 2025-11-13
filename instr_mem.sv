`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 09:46:21 PM
// Design Name: 
// Module Name: instr_mem
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


module instr_mem(
input logic [31:2] addr,
output logic [31:0] instr
    );
    
 logic [31:0] mem[0:255];
 
 initial begin
    $readmemh("program.mem", mem);
    #1;
    $display("IMEM[0] = %h", mem[0]);  // debug
  end
  
  always_comb begin
   instr = mem[addr]; // lower bits for 256-deep
  end
  
endmodule
