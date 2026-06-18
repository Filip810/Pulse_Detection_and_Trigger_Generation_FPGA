// =============================================================================
// Testbench: tb_pulse_detector
// =============================================================================
`timescale 1ns/1ps

module tb_pulse_detector;

localparam DATA_WIDTH   = 16;
localparam BUFFER_DEPTH = 256;
localparam PTR_WIDTH    = 8;
localparam CLK_PERIOD   = 10;

reg                    clk          = 0;
reg                    rst_n        = 0;
reg  [DATA_WIDTH-1:0]  sample       = 0;
reg                    sample_valid = 0;
reg  [DATA_WIDTH-1:0]  threshold    = 1000;
reg  [DATA_WIDTH-1:0]  hysteresis   = 100;
reg  [PTR_WIDTH-1:0]   pre_samples  = 8;
reg  [PTR_WIDTH-1:0]   post_samples = 16;
reg                    enable       = 0;
reg  [PTR_WIDTH-1:0]   rd_addr      = 0;

wire                   trigger_flag;
wire [31:0]            trigger_time;
wire [PTR_WIDTH-1:0]   buf_ptr_start;
wire [PTR_WIDTH-1:0]   buf_ptr_end;
wire                   capture_done;
wire [DATA_WIDTH-1:0]  rd_data;

// Latch trigger_flag bo pulsuje tylko 1 takt
reg trigger_seen = 0;
always @(posedge clk) begin
    if (!rst_n)
        trigger_seen <= 0;
    else if (trigger_flag)
        trigger_seen <= 1;
end

pulse_detector #(
    .DATA_WIDTH   (DATA_WIDTH),
    .BUFFER_DEPTH (BUFFER_DEPTH),
    .PTR_WIDTH    (PTR_WIDTH)
) dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .sample        (sample),
    .sample_valid  (sample_valid),
    .threshold     (threshold),
    .hysteresis    (hysteresis),
    .pre_samples   (pre_samples),
    .post_samples  (post_samples),
    .enable        (enable),
    .trigger_flag  (trigger_flag),
    .trigger_time  (trigger_time),
    .buf_ptr_start (buf_ptr_start),
    .buf_ptr_end   (buf_ptr_end),
    .capture_done  (capture_done),
    .rd_addr       (rd_addr),
    .rd_data       (rd_data)
);

always #(CLK_PERIOD/2) clk = ~clk;

task send_sample;
    input [DATA_WIDTH-1:0] s;
    begin
        @(posedge clk);
        sample       <= s;
        sample_valid <= 1;
        @(posedge clk);
        sample_valid <= 0;
    end
endtask

task wait_clk;
    input integer n;
    begin
        repeat(n) @(posedge clk);
    end
endtask

integer i;
integer errors = 0;

initial begin
    $display("=== TB START: pulse_detector ===");

    // 1. Reset
    rst_n  = 0;
    enable = 0;
    wait_clk(5);
    rst_n = 1;
    wait_clk(2);
    $display("[%0t] Reset released", $time);

    // 2. Baseline samples
    enable = 1;
    trigger_seen = 0;
    $display("[%0t] Sending 20 baseline samples (value=500)", $time);
    for (i = 0; i < 20; i = i+1)
        send_sample(16'd500);

    // 3. Trigger sample
    $display("[%0t] Sending trigger sample (value=1200 > threshold=1000)", $time);
    send_sample(16'd1200);
    // Czekaj max 5 taktow na trigger_seen (latch)
    wait_clk(5);

    if (trigger_seen !== 1) begin
        $display("ERROR: trigger_flag not seen after threshold crossing!");
        errors = errors + 1;
    end else
        $display("[%0t] PASS: trigger_flag asserted, trigger_time=%0d",
                  $time, trigger_time);

    // 4. Utrzymaj wysoki, potem spadnij ponizej histerezy
    repeat(5) send_sample(16'd1200);
    $display("[%0t] Dropping below hysteresis (value=850)", $time);
    send_sample(16'd850);

    // 5. Czekaj na capture_done
    repeat(post_samples + 5) send_sample(16'd500);
    wait_clk(5);

    if (capture_done !== 1) begin
        $display("ERROR: capture_done not set!");
        errors = errors + 1;
    end else
        $display("[%0t] PASS: capture_done asserted. buf[%0d..%0d]",
                  $time, buf_ptr_start, buf_ptr_end);

    // 6. Odczyt bufora
    $display("[%0t] Reading full capture window buf[%0d..%0d]:", $time, buf_ptr_start, buf_ptr_end);
    for (i = buf_ptr_start; i <= buf_ptr_end; i = i+1) begin
        rd_addr = i;
        @(posedge clk); #1;
        $display("  buf[%0d] = %0d", rd_addr, rd_data);
    end

    // 7. Re-arm
    enable = 0; wait_clk(2);
    trigger_seen = 0;
    enable = 1; wait_clk(2);
    $display("[%0t] Re-armed", $time);

    // 8. Brak triggera gdy enable=0
    enable = 0;
    send_sample(16'd2000);
    wait_clk(5);
    if (trigger_seen !== 0) begin
        $display("ERROR: trigger_flag set while enable=0!");
        errors = errors + 1;
    end else
        $display("[%0t] PASS: no trigger when disabled", $time);

    wait_clk(10);
    if (errors == 0)
        $display("=== ALL TESTS PASSED ===");
    else
        $display("=== %0d TEST(S) FAILED ===", errors);

    $finish;
end

initial begin
    #500000;
    $display("TIMEOUT!");
    $finish;
end

initial begin
    $dumpfile("tb_pulse_detector.vcd");
    $dumpvars(0, tb_pulse_detector);
end

endmodule