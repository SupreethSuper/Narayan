`include "nar_params.vh"
`include "scheduler_params.vh"


module scheduler #(
    parameter DATA_WIDTH  = NAR_NUM_BITS,
    parameter ROWS        = NAR_MAT_ROWS,
    parameter COLS        = NAR_MAT_COLS,
    parameter NUM_UNITS   = SCHED_MEM_UNITS,
    parameter LOCAL_ADDR  = $clog2(ROWS * COLS),
    parameter GLOBAL_ADDR = $clog2(NUM_UNITS * ROWS * COLS)
)
(
    input  logic clk,
    input  logic rw_,
    input  logic cs,
    input  logic rst,      // active-low async reset

    input  logic [DATA_WIDTH-1:0]  data_in,
    output logic [DATA_WIDTH-1:0]  data_out,
    output logic [NUM_UNITS-1:0]   cs_out,
    output logic [LOCAL_ADDR-1:0]  rd_addr,   // local address into selected memory
    output logic                   rw_out,
    output logic                   rst_out,
	 output logic                   clk_out
);

    localparam TOTAL_ADDRS = NUM_UNITS * ROWS * COLS;  // 100

    assign data_out = data_in;
    assign rw_out   = rw_;
    assign rst_out  = rst;
	 assign clk_out  = clk;

    // ----------------------------------------------------------------
    // Internal beat counter
    // Advances each write-active cycle (cs=1, rw_=0).
    // Wraps back to 0 after the last beat (TOTAL_ADDRS-1).
    // ----------------------------------------------------------------
    logic [GLOBAL_ADDR-1:0] beat_cnt;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            beat_cnt <= '0;
        else if (cs && !rw_)
            beat_cnt <= (beat_cnt == GLOBAL_ADDR'(TOTAL_ADDRS - 1)) ? '0 : beat_cnt + 1'b1;
    end

    // ----------------------------------------------------------------
    // Decode beat_cnt into (mem_idx, local_addr)
    //   super_row    = beat_cnt / (NUM_UNITS * COLS)   // which row
    //   pos_in_super = beat_cnt % (NUM_UNITS * COLS)   // offset in super-row
    //   mem_idx      = pos_in_super / COLS             // which memory
    //   col_in_row   = pos_in_super % COLS             // which column
    //   local_addr   = super_row * COLS + col_in_row
    // ----------------------------------------------------------------
    logic [GLOBAL_ADDR-1:0] super_row;
    logic [GLOBAL_ADDR-1:0] pos_in_super;
    logic [GLOBAL_ADDR-1:0] mem_idx;
    logic [GLOBAL_ADDR-1:0] col_in_row;

    always_comb begin
        super_row    = beat_cnt / (NUM_UNITS * COLS);
        pos_in_super = beat_cnt % (NUM_UNITS * COLS);
        mem_idx      = pos_in_super / COLS;
        col_in_row   = pos_in_super % COLS;
    end

    assign rd_addr = LOCAL_ADDR'(super_row * COLS + col_in_row);

    genvar i;
    generate
        for (i = 0; i < NUM_UNITS; i++) begin : cs_gen
            // Write: only the addressed unit gets cs_out=1 (sequential load)
            // Read : all units get cs_out=1 (parallel readout)
            assign cs_out[i] = cs && (!rw_ ? (mem_idx == GLOBAL_ADDR'(i)) : 1'b1);
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (cs && !rw_ && beat_cnt < 10)
            $display("[%0t] beat_cnt=%2d mem_idx=%d cs_out=%b rd_addr=%2d data_in=%d",
                     $time, beat_cnt, mem_idx, cs_out, rd_addr, data_in);
    end


endmodule
