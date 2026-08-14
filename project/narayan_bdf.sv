`include "nar_params.vh"
`include "scheduler_params.vh"

module narayan_bdf #(
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
    output logic [DATA_WIDTH-1:0]  mem1_out,
    output logic [DATA_WIDTH-1:0]  mem2_out,
    output logic [DATA_WIDTH-1:0]  mem3_out,
    output logic [DATA_WIDTH-1:0]  mem4_out
);

    typedef enum logic [NUM_UNITS-1:0] { MEM_0, MEM_1, MEM_2, MEM_3 } mem_sel_e;

    logic                  clk_w;
    logic                  rw_w;
    logic                  rst_w;
    logic [DATA_WIDTH-1:0] data_w;
    logic [LOCAL_ADDR-1:0] addr_w;
    logic [NUM_UNITS-1:0]  cs_w;

    scheduler #(
        .DATA_WIDTH  (DATA_WIDTH),
        .ROWS        (ROWS),
        .COLS        (COLS),
        .NUM_UNITS   (NUM_UNITS),
        .LOCAL_ADDR  (LOCAL_ADDR),
        .GLOBAL_ADDR (GLOBAL_ADDR)
    ) u_scheduler (
        .clk      (clk),
        .rw_      (rw_),
        .cs       (cs),
        .rst      (rst),
        .next     (next),
        .data_in  (data_in),
        .clk_out  (clk_w),
        .rw_out   (rw_w),
        .rst_out  (rst_w),
        .data_out (data_w),
        .cs_out   (cs_w),
        .rd_addr  (addr_w)
    );

    scratchpad_memory #(
        .DATA_WIDTH  (DATA_WIDTH),
        .ROWS        (ROWS),
        .COLS        (COLS),
        .MEM_ADDRESS (LOCAL_ADDR)
    ) u_mem0 (
        .clk      (clk_w),
        .rw_      (rw_w),
        .cs       (cs_w[MEM_0]),
        .rst      (rst_w),
        .data_in  (data_w),
        .wr_addr  (addr_w),
        .data_out (mem1_out)
    );

    scratchpad_memory #(
        .DATA_WIDTH  (DATA_WIDTH),
        .ROWS        (ROWS),
        .COLS        (COLS),
        .MEM_ADDRESS (LOCAL_ADDR)
    ) u_mem1 (
        .clk      (clk_w),
        .rw_      (rw_w),
        .cs       (cs_w[MEM_1]),
        .rst      (rst_w),
        .data_in  (data_w),
        .wr_addr  (addr_w),
        .data_out (mem2_out)
    );

    scratchpad_memory #(
        .DATA_WIDTH  (DATA_WIDTH),
        .ROWS        (ROWS),
        .COLS        (COLS),
        .MEM_ADDRESS (LOCAL_ADDR)
    ) u_mem2 (
        .clk      (clk_w),
        .rw_      (rw_w),
        .cs       (cs_w[MEM_2]),
        .rst      (rst_w),
        .data_in  (data_w),
        .wr_addr  (addr_w),
        .data_out (mem3_out)
    );

    scratchpad_memory #(
        .DATA_WIDTH  (DATA_WIDTH),
        .ROWS        (ROWS),
        .COLS        (COLS),
        .MEM_ADDRESS (LOCAL_ADDR)
    ) u_mem3 (
        .clk      (clk_w),
        .rw_      (rw_w),
        .cs       (cs_w[MEM_3]),
        .rst      (rst_w),
        .data_in  (data_w),
        .wr_addr  (addr_w),
        .data_out (mem4_out)
    );

endmodule
