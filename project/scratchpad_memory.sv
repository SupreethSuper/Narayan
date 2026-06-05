
`include "nar_params.vh"

module scratchpad_memory #(
    parameter DATA_WIDTH      = NAR_NUM_BITS,
    parameter ROWS            = NAR_MAT_ROWS,
    parameter COLS            = NAR_MAT_COLS,
    parameter MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP,
    parameter MEM_ADDRESS     = $clog2(NAR_MAT_ROWS * NAR_MAT_COLS)
)
(
    input  logic clk,      // Clock
    input  logic rw_,      // 0 = Write, 1 = Read
    input  logic cs,       // chip select
    input  logic rst,      // reset

    input  logic [MEM_ADDRESS-1:0] wr_addr,

    input  logic [DATA_WIDTH-1:0] data_in,

    output logic [DATA_WIDTH-1:0] data_out
);

    localparam DEPTH = ROWS * COLS;

    //definitions of ZERO and ONE
    localparam logic [DATA_WIDTH-1:0] MEM_ZERO = {DATA_WIDTH{1'b0}};
    localparam logic [DATA_WIDTH-1:0] MEM_ONE = {DATA_WIDTH{1'b1}};
    localparam int FSM_STATES = 3;

    localparam logic [FSM_STATES-1:0] RESET_STATE = {FSM_STATES{1'b0}};
    localparam logic [FSM_STATES-1:0] READ_STATE  = {{FSM_STATES-1{1'b0}}, 1'b1};
    localparam logic [FSM_STATES-1:0] WRITE_STATE = {{FSM_STATES-2{1'b0}}, 1'b1, 1'b0};

    logic [FSM_STATES-1:0] fsm_state;
    logic [FSM_STATES-1:0] next_fsm_state;

    // assign next_fsm_state = fsm_state;

    logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            fsm_state <= RESET_STATE;
        end
        else begin
            fsm_state <= next_fsm_state;
        end
    end

    always_comb begin
        next_fsm_state = fsm_state;

        if (!cs) begin
            next_fsm_state = RESET_STATE;
        end
        else begin
            case (fsm_state)
                RESET_STATE: begin
                    if (!rw_)
                        next_fsm_state = WRITE_STATE;
                    else
                        next_fsm_state = RESET_STATE;
                end

                READ_STATE: begin
                    if (rw_)
                        next_fsm_state = READ_STATE;
                    else
                        next_fsm_state = WRITE_STATE;
                end

                WRITE_STATE: begin
                    if (rw_)
                        next_fsm_state = READ_STATE;
                    else
                        next_fsm_state = WRITE_STATE;
                end

                default: begin
                    next_fsm_state = RESET_STATE;
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (fsm_state == WRITE_STATE) begin
            memory[wr_addr] <= data_in;
        end
    end

    always_ff @(posedge clk or negedge rst) begin : ram_unit
        if (!rst) begin
            data_out <= MEM_ZERO;
        end
        else if (!cs) begin
            data_out <= MEM_ZERO;
        end
        else begin
            case (fsm_state)
                READ_STATE: begin
                    data_out <= memory[wr_addr];
                end

                WRITE_STATE: begin
                    data_out <= data_out;
                end

                RESET_STATE: begin
                    data_out <= MEM_ZERO;
                end

                default: begin
                    data_out <= MEM_ZERO;
                end
            endcase
        end
    end


endmodule
