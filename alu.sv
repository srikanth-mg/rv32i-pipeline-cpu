`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/12/2025 09:42:07 PM
// Design Name: 
// Module Name: alu
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


module alu(
input logic [31:0] rs1_data,rs2_data,
input logic [3:0] alu_ctrl,
output logic [31:0] rd
    );
    
    always_comb begin
    unique case (alu_ctrl)
      4'b0000: begin rd = rs1_data + rs2_data;  end                         // ADD/ADDI
      4'b1000: begin rd = rs1_data - rs2_data;   end                        // SUB
      4'b0111: begin rd = rs1_data & rs2_data;    end                       // AND
      4'b0110: begin rd = rs1_data | rs2_data;    end                       // OR
      4'b0010: begin rd = ($signed(rs1_data) < $signed(rs2_data)) ? 32'd1 : 32'd0; end // SLT
      default: begin rd = 32'd0; end
    endcase
  end
endmodule
