module pulse_detector #(
    parameter DATA_WIDTH   = 16,
    parameter BUFFER_DEPTH = 256, 
    parameter PTR_WIDTH    = 8 
)(
    // Clock & Reset
    input  wire                   clk,
    input  wire                   rst_n,

    // Sample input
    input  wire [DATA_WIDTH-1:0]  sample,
    input  wire                   sample_valid,

    // Configuration
    input  wire [DATA_WIDTH-1:0]  threshold,    // detection level
    input  wire [DATA_WIDTH-1:0]  hysteresis,   // deadband below threshold
    input  wire [PTR_WIDTH-1:0]   pre_samples,  // samples to keep before trigger
    input  wire [PTR_WIDTH-1:0]   post_samples, // samples to capture after trigger
    input  wire                   enable,        // global enable

    // Outputs
    output reg                    trigger_flag,  // pulsed 1 clk when trigger fires
    output reg  [31:0]            trigger_time,  // free running timestamp
    output reg  [PTR_WIDTH-1:0]   buf_ptr_start, // start pointer of captured window
    output reg  [PTR_WIDTH-1:0]   buf_ptr_end,   // end pointer of captured window
    output reg                    capture_done,  // high when post-capture complete

    // Circular buffer read port 
    input  wire [PTR_WIDTH-1:0]   rd_addr,
    output wire [DATA_WIDTH-1:0]  rd_data
);

// ---------------------------------------------------------------------------
// 1. CIRCULAR BUFFER (simple dual-port BRAM inferred)
// ---------------------------------------------------------------------------
reg [DATA_WIDTH-1:0] circ_buf [0:BUFFER_DEPTH-1];
reg [PTR_WIDTH-1:0]  wr_ptr;

assign rd_data = circ_buf[rd_addr];

always @(posedge clk) begin
    if (sample_valid && enable)
        circ_buf[wr_ptr] <= sample;
end

// ---------------------------------------------------------------------------
// 2. STATE MACHINE
// ---------------------------------------------------------------------------
// States
localparam IDLE      = 2'd0;
localparam ARMED     = 2'd1; 
localparam CAPTURING = 2'd2; 
localparam DONE      = 2'd3; 

reg [1:0]           state;
reg [PTR_WIDTH-1:0] post_cnt;
reg [31:0]          timestamp;

wire above_threshold  = (sample >= threshold);
wire below_hysteresis = (sample <= (threshold - hysteresis));

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state         <= IDLE;
        wr_ptr        <= 0;
        post_cnt      <= 0;
        timestamp     <= 0;
        trigger_flag  <= 0;
        trigger_time  <= 0;
        buf_ptr_start <= 0;
        buf_ptr_end   <= 0;
        capture_done  <= 0;
    end else begin
        timestamp <= timestamp + 1;

        trigger_flag <= 0;

        if (!enable) begin
            state        <= IDLE;
            capture_done <= 0;
        end else if (sample_valid) begin
            wr_ptr <= wr_ptr + 1;

            case (state)
                // ── IDLE: wait for sample to cross threshold ──────────────
                IDLE: begin
                    capture_done <= 0;
                    if (above_threshold) begin
                        state        <= ARMED;
                        trigger_flag <= 1;
                        trigger_time <= timestamp;
                        // pre_samples back from CURRENT wr_ptr
                        buf_ptr_start <= wr_ptr - pre_samples;
                        post_cnt      <= 0;
                    end
                end

                // ── ARMED: signal is high, wait for it to drop ────────────
                ARMED: begin
                    if (below_hysteresis)
                        state <= CAPTURING;
                end

                // ── CAPTURING: collect post_samples more samples ──────────
                CAPTURING: begin
                    post_cnt <= post_cnt + 1;
                    if (post_cnt >= post_samples - 1) begin
                        buf_ptr_end  <= wr_ptr;
                        capture_done <= 1;
                        state        <= DONE;
                    end
                end

                // ── DONE: wait for software to re-arm (toggle enable) ─────
                DONE: begin
                    capture_done <= 1;
                    // Re-arm: software clears enable then sets it again
                end

                default: state <= IDLE;
            endcase
        end
    end
end

endmodule
