`timescale 1ns / 1ps

module data_mem(
  input  logic        clk,
  input  logic [31:2] addr,    // word aligned
  input  logic        we,
  input  logic [31:0] wd,
  output logic [31:0] rd
);
  logic [31:0] mem [0:255];

  always_ff @(posedge clk) begin
    if (we) mem[addr[9:2]] <= wd; // for SW operation
  end
  assign rd = mem[addr[9:2]];  //for LW operation
endmodule
