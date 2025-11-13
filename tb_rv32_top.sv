`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 10:29:14 PM
// Design Name: 
// Module Name: tb_rv32_top
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


module tb_rv32_top;
  logic clk = 0, rst_n = 0;
  rv32_top R1(.clk(clk), .rst_n(rst_n));

  always begin 
  #5 clk = ~clk;
 end
 
  initial begin
    $display("RV32I 5-stage (SV) smoke test");
    rst_n = 0;
    #40;            // wait a few cycles
    rst_n = 1;      // deassert reset (release
    repeat (200) @(posedge clk);
    $display("DONE");
    $finish;
  end
endmodule

