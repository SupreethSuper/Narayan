`include "nar_params.vh"
`include "scheduler_params.vh"


module pipeline1#(
    parameter DATA_WIDTH = NAR_NUM_BITS,
    parameter NUM_UNITS = SCHED_MEM_UNITS
)

(
    input logic                  clk,
    input logic                  rst,
    input logic                  cs,
    input logic [DATA_WIDTH-1:0] mem1_out,
    input logic [DATA_WIDTH-1:0] mem2_out,
    input logic [DATA_WIDTH-1:0] mem3_out,
    input logic [DATA_WIDTH-1:0] mem4_out,

    output logic                  pipe1_clk,
    output logic                  pipe1_rst,
    output logic                  pipe1_cs,
    output logic [DATA_WIDTH-1:0] pipe1_mem1_out,
    output logic [DATA_WIDTH-1:0] pipe1_mem2_out,
    output logic [DATA_WIDTH-1:0] pipe1_mem3_out,
    output logic [DATA_WIDTH-1:0] pipe1_mem4_out

);

    always_comb begin : pipeline
        

        
        pipe1_clk = clk;
        pipe1_rst = rst;
        pipe1_cs = cs;
        pipe1_mem1_out = mem1_out;
        pipe1_mem2_out = mem2_out;
        pipe1_mem3_out = mem3_out;
        pipe1_mem4_out = mem4_out;
    
    end


endmodule