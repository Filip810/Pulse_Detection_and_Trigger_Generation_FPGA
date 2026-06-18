// =============================================================================
// Module: pulse_detector_axi
// Description: AXI4-Lite slave wrapper for pulse_detector.
//              Exposes configuration registers and status over AXI-Lite.
//
// Register Map (32-bit, word-aligned):
//   0x00  CTRL        [0]=enable, [1]=soft_reset
//   0x04  THRESHOLD   [15:0]
//   0x08  HYSTERESIS  [15:0]
//   0x0C  PRE_SAMPLES [7:0]
//   0x10  POST_SAMPLES[7:0]
//   0x14  STATUS (RO) [0]=trigger_flag, [1]=capture_done
//   0x18  TRIG_TIME(RO) [31:0] timestamp at trigger
//   0x1C  BUF_START(RO) [7:0]
//   0x20  BUF_END  (RO) [7:0]
//   0x24  BUF_DATA (RO) [15:0] — reads circ buffer at RD_ADDR
//   0x28  RD_ADDR      [7:0]   — set before reading BUF_DATA
// =============================================================================

module pulse_detector_axi #(
    parameter DATA_WIDTH   = 16,
    parameter BUFFER_DEPTH = 256,
    parameter PTR_WIDTH    = 8,
    parameter AXI_ADDR_W   = 6,   // covers 0x00..0x28 → 6 bits sufficient
    parameter AXI_DATA_W   = 32
)(
    // AXI4-Lite Slave interface
    input  wire                    s_axi_aclk,
    input  wire                    s_axi_aresetn,

    // Write address channel
    input  wire [AXI_ADDR_W-1:0]  s_axi_awaddr,
    input  wire                    s_axi_awvalid,
    output reg                     s_axi_awready,

    // Write data channel
    input  wire [AXI_DATA_W-1:0]  s_axi_wdata,
    input  wire [AXI_DATA_W/8-1:0] s_axi_wstrb,
    input  wire                    s_axi_wvalid,
    output reg                     s_axi_wready,

    // Write response channel
    output reg  [1:0]              s_axi_bresp,
    output reg                     s_axi_bvalid,
    input  wire                    s_axi_bready,

    // Read address channel
    input  wire [AXI_ADDR_W-1:0]  s_axi_araddr,
    input  wire                    s_axi_arvalid,
    output reg                     s_axi_arready,

    // Read data channel
    output reg  [AXI_DATA_W-1:0]  s_axi_rdata,
    output reg  [1:0]              s_axi_rresp,
    output reg                     s_axi_rvalid,
    input  wire                    s_axi_rready,

    // Sample input (from ADC or simulation)
    input  wire [DATA_WIDTH-1:0]   sample,
    input  wire                    sample_valid
);

// ---------------------------------------------------------------------------
// Internal registers
// ---------------------------------------------------------------------------
reg [DATA_WIDTH-1:0] reg_threshold;
reg [DATA_WIDTH-1:0] reg_hysteresis;
reg [PTR_WIDTH-1:0]  reg_pre_samples;
reg [PTR_WIDTH-1:0]  reg_post_samples;
reg                  reg_enable;
reg                  reg_soft_reset;
reg [PTR_WIDTH-1:0]  reg_rd_addr;

// Status (from core)
wire                   trigger_flag;
wire [31:0]            trigger_time;
wire [PTR_WIDTH-1:0]   buf_ptr_start;
wire [PTR_WIDTH-1:0]   buf_ptr_end;
wire                   capture_done;
wire [DATA_WIDTH-1:0]  rd_data;

// Internal reset
wire rst_n = s_axi_aresetn & ~reg_soft_reset;

// ---------------------------------------------------------------------------
// Instantiate core
// ---------------------------------------------------------------------------
pulse_detector #(
    .DATA_WIDTH   (DATA_WIDTH),
    .BUFFER_DEPTH (BUFFER_DEPTH),
    .PTR_WIDTH    (PTR_WIDTH)
) u_core (
    .clk           (s_axi_aclk),
    .rst_n         (rst_n),
    .sample        (sample),
    .sample_valid  (sample_valid),
    .threshold     (reg_threshold),
    .hysteresis    (reg_hysteresis),
    .pre_samples   (reg_pre_samples),
    .post_samples  (reg_post_samples),
    .enable        (reg_enable),
    .trigger_flag  (trigger_flag),
    .trigger_time  (trigger_time),
    .buf_ptr_start (buf_ptr_start),
    .buf_ptr_end   (buf_ptr_end),
    .capture_done  (capture_done),
    .rd_addr       (reg_rd_addr),
    .rd_data       (rd_data)
);

// ---------------------------------------------------------------------------
// AXI Write logic
// ---------------------------------------------------------------------------
reg [AXI_ADDR_W-1:0] aw_addr_lat;

always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        s_axi_awready  <= 0;
        s_axi_wready   <= 0;
        s_axi_bvalid   <= 0;
        s_axi_bresp    <= 2'b00;
        reg_enable      <= 0;
        reg_soft_reset  <= 0;
        reg_threshold   <= 16'd1000;
        reg_hysteresis  <= 16'd100;
        reg_pre_samples <= 8'd16;
        reg_post_samples<= 8'd32;
        reg_rd_addr     <= 0;
        aw_addr_lat     <= 0;
    end else begin
        // Single-cycle ready pulses
        s_axi_awready <= 0;
        s_axi_wready  <= 0;
        reg_soft_reset <= 0;  // auto-clear

        if (s_axi_awvalid && !s_axi_awready) begin
            s_axi_awready <= 1;
            aw_addr_lat   <= s_axi_awaddr;
        end

        if (s_axi_wvalid && !s_axi_wready) begin
            s_axi_wready <= 1;
            case (aw_addr_lat[5:2])   // word index
                4'h0: begin  // CTRL
                    reg_enable     <= s_axi_wdata[0];
                    reg_soft_reset <= s_axi_wdata[1];
                end
                4'h1: reg_threshold    <= s_axi_wdata[DATA_WIDTH-1:0];
                4'h2: reg_hysteresis   <= s_axi_wdata[DATA_WIDTH-1:0];
                4'h3: reg_pre_samples  <= s_axi_wdata[PTR_WIDTH-1:0];
                4'h4: reg_post_samples <= s_axi_wdata[PTR_WIDTH-1:0];
                4'hA: reg_rd_addr      <= s_axi_wdata[PTR_WIDTH-1:0];
                default: ;
            endcase
        end

        // Write response
        if (s_axi_wready) begin
            s_axi_bvalid <= 1;
            s_axi_bresp  <= 2'b00; // OKAY
        end
        if (s_axi_bvalid && s_axi_bready)
            s_axi_bvalid <= 0;
    end
end

// ---------------------------------------------------------------------------
// AXI Read logic
// ---------------------------------------------------------------------------
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        s_axi_arready <= 0;
        s_axi_rvalid  <= 0;
        s_axi_rdata   <= 0;
        s_axi_rresp   <= 2'b00;
    end else begin
        s_axi_arready <= 0;

        if (s_axi_arvalid && !s_axi_arready) begin
            s_axi_arready <= 1;
            s_axi_rvalid  <= 1;
            s_axi_rresp   <= 2'b00;

            case (s_axi_araddr[5:2])
                4'h0: s_axi_rdata <= {30'b0, reg_soft_reset, reg_enable};
                4'h1: s_axi_rdata <= {16'b0, reg_threshold};
                4'h2: s_axi_rdata <= {16'b0, reg_hysteresis};
                4'h3: s_axi_rdata <= {24'b0, reg_pre_samples};
                4'h4: s_axi_rdata <= {24'b0, reg_post_samples};
                4'h5: s_axi_rdata <= {30'b0, capture_done, trigger_flag};
                4'h6: s_axi_rdata <= trigger_time;
                4'h7: s_axi_rdata <= {24'b0, buf_ptr_start};
                4'h8: s_axi_rdata <= {24'b0, buf_ptr_end};
                4'h9: s_axi_rdata <= {16'b0, rd_data};
                4'hA: s_axi_rdata <= {24'b0, reg_rd_addr};
                default: s_axi_rdata <= 32'hDEAD_BEEF;
            endcase
        end

        if (s_axi_rvalid && s_axi_rready)
            s_axi_rvalid <= 0;
    end
end

endmodule
