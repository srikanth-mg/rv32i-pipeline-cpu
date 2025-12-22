`timescale 1ns/1ps

module tb_rv32_top;
    logic clk;
    logic rst_n;

    // DUT
    rv32_top dut (
        .clk  (clk),
        .rst_n(rst_n)
    );

    // Clock: 100MHz-ish (10ns period)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // VCD dump (Verilator --trace will honor this)
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_rv32_top);
    end
    
    // --- WB / Regfile commit trace ---
always_ff @(posedge clk) begin
  if (rst_n) begin
    if (dut.RF1.we && (dut.RF1.wa != 0)) begin
      $display("[%0t] WB COMMIT: x%0d <= 0x%08h (%0d)",
               $time, dut.RF1.wa, dut.RF1.wd, dut.RF1.wd);
    end
  end
end


    // Reset + run
    initial begin
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // Run enough cycles for lw/add/addi to flow through pipeline
        repeat (80) @(posedge clk);
        $display("SIM DONE");
        $finish;
    end
endmodule
