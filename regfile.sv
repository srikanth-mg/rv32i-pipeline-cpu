`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 09:36:49 PM
// Design Name: 
// Module Name: regfile
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
module regfile(
input logic clk,
input logic [4:0] ra1, ra2, wa,
input logic we,
input logic [31:0] wd,
output logic [31:0] rd1, rd2
    );
    
    logic [31:0] x[31:0];
    
    assign rd1 = (ra1 == 0)? 32'd0 : x[ra1];
    assign rd2 = (ra2 == 0)? 32'd0 : x[ra2];
    
    always@(posedge clk) begin
    if((we && wa) != 0) begin 
    x[wa] <= wd;
    end
    end
    
endmodule
