`include "nar_params.vh"
`include "scheduler_params.vh"

// ============================================================
// stage1_pipeline
// Structural top module that composes:
//   narayan_bdf  (scheduler + 4x scratchpad_memory)
//        |  mem1_out..mem4_out
//        v
//   pipeline1    (combinational forwarding stage)
//
// The four memory outputs of narayan_bdf feed pipeline1, which
// forwards them (plus the top-level clk/rst/cs) one hop downstream
// as the pipe1_* outputs. The memN_out ports are also exposed so a
// testbench can confirm the pipeline mirrors them.
// ============================================================
module stage1_pipeline #(
    parameter DATA_WIDTH  = NAR_NUM_BITS,
    parameter ROWS        = NAR_MAT_ROWS,
    parameter COLS        = NAR_MAT_COLS,
    parameter NUM_UNITS   = SCHED_MEM_UNITS,
    parameter LOCAL_ADDR  = $clog2(ROWS * COLS),
    parameter GLOBAL_ADDR = $clog2(NUM_UNITS * ROWS * COLS)
)
(
    input  logic                   clk,
    input  logic                   rw_,
    input  logic                   rst,
    input  logic                   cs,
    input  logic                   next,
    input  logic [DATA_WIDTH-1:0]  data_in,

    // memory outputs (exposed for observation / checking)
    output logic [DATA_WIDTH-1:0]  mem1_out,
    output logic [DATA_WIDTH-1:0]  mem2_out,
    output logic [DATA_WIDTH-1:0]  mem3_out,
    output logic [DATA_WIDTH-1:0]  mem4_out,

    // pipeline1 stage outputs
    output logic                   pipe1_clk,
    output logic                   pipe1_rst,
    output logic                   pipe1_cs,
    output logic [DATA_WIDTH-1:0]  pipe1_mem1_out,
    output logic [DATA_WIDTH-1:0]  pipe1_mem2_out,
    output logic [DATA_WIDTH-1:0]  pipe1_mem3_out,
    output logic [DATA_WIDTH-1:0]  pipe1_mem4_out
);

    // internal nets carrying narayan_bdf memory outputs into pipeline1
    logic [DATA_WIDTH-1:0] mem1_w;
    logic [DATA_WIDTH-1:0] mem2_w;
    logic [DATA_WIDTH-1:0] mem3_w;
    logic [DATA_WIDTH-1:0] mem4_w;

    narayan_bdf #(
        .DATA_WIDTH  (DATA_WIDTH),
        .ROWS        (ROWS),
        .COLS        (COLS),
        .NUM_UNITS   (NUM_UNITS),
        .LOCAL_ADDR  (LOCAL_ADDR),
        .GLOBAL_ADDR (GLOBAL_ADDR)
    ) u_bdf (
        .clk      (clk),
        .rw_      (rw_),
        .rst      (rst),
        .cs       (cs),
        .next     (next),
        .data_in  (data_in),
        .mem1_out (mem1_w),
        .mem2_out (mem2_w),
        .mem3_out (mem3_w),
        .mem4_out (mem4_w)
    );

    pipeline1 #(
        .DATA_WIDTH (DATA_WIDTH),
        .NUM_UNITS  (NUM_UNITS)
    ) u_pipe (
        .clk            (clk),
        .rst            (rst),
        .cs             (cs),
        .mem1_out       (mem1_w),
        .mem2_out       (mem2_w),
        .mem3_out       (mem3_w),
        .mem4_out       (mem4_w),
        .pipe1_clk      (pipe1_clk),
        .pipe1_rst      (pipe1_rst),
        .pipe1_cs       (pipe1_cs),
        .pipe1_mem1_out (pipe1_mem1_out),
        .pipe1_mem2_out (pipe1_mem2_out),
        .pipe1_mem3_out (pipe1_mem3_out),
        .pipe1_mem4_out (pipe1_mem4_out)
    );

    // expose the memory outputs at the top level
    assign mem1_out = mem1_w;
    assign mem2_out = mem2_w;
    assign mem3_out = mem3_w;
    assign mem4_out = mem4_w;

endmodule
