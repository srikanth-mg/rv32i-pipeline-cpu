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

  logic clk   = 0;
  logic rst_n = 0;

  // DUT instance
  rv32_top dut (
    .clk  (clk),
    .rst_n(rst_n)
  );

  // Clock: 10 ns period
  always #5 clk = ~clk;

  initial begin
    $display("RV32I 5-stage (SV) - forwarding test");
    rst_n = 0;
    repeat (5) @(posedge clk);          // hold reset low for a few cycles
    rst_n = 1;    // release reset
   repeat (200) @(posedge clk);         // let it run for a while
    $display("Simulation finished");
    $finish;
  end

endmodule

