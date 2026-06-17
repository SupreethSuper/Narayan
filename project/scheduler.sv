`include "nar_params.vh"
`include "scheduler_params.vh"


module scheduler #(
    parameter DATA_WIDTH  = NAR_NUM_BITS,
    parameter ROWS        = NAR_MAT_ROWS,
    parameter COLS        = NAR_MAT_COLS,
    parameter MEM_ADDRESS = $clog2(NAR_MAT_ROWS * NAR_MAT_COLS),
    parameter NUM_UNITS   = SCHED_MEM_UNITS
)
(
    input  logic clk,      // Clock
    input  logic rw_,      // 0 = Write, 1 = Read
    input  logic cs,       // chip select
    input  logic rst,      // reset (active-low, async)

    input  logic [MEM_ADDRESS-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0]  data_in,

    output logic [DATA_WIDTH-1:0]  data_out,
    output logic [NUM_UNITS-1:0]   cs_out,
    output logic [MEM_ADDRESS-1:0] rd_addr,
    output logic                   rw_out,
    output logic                   rst_out
);


    assign data_out = data_in;
    assign rw_out = rw_;
    assign rd_addr = wr_addr;
    assign rst_out = rst;

    for(genvar i = 0; i < NUM_UNITS; i++) begin : cs_gen
        assign cs_out[i] = cs && (wr_addr >= (i * (ROWS * COLS))) && (wr_addr < ((i + 1) * (ROWS * COLS)));
    end


endmodule