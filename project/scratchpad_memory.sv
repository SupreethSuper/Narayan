`include "nar_params.vh"

module scratchpad_memory #(
    parameter DATA_WIDTH  = NAR_NUM_BITS,
    parameter ROWS        = NAR_MAT_ROWS,
    parameter COLS        = NAR_MAT_COLS,
    parameter MEM_ADDRESS = $clog2(NAR_MAT_ROWS * NAR_MAT_COLS)
)
(
    input  logic clk,      // Clock
    input  logic rw_,      // 0 = Write, 1 = Read
    input  logic cs,       // chip select
    input  logic rst,      // reset (active-low, async)

    input  logic [MEM_ADDRESS-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0]  data_in,

    output logic [DATA_WIDTH-1:0]  data_out
);

    localparam logic [DATA_WIDTH-1:0] MEM_ZERO = {DATA_WIDTH{1'b0}};
    localparam int FSM_STATES = 3;

    // localparam logic [FSM_STATES-1:0] RESET_STATE = {FSM_STATES{1'b0}};
    // localparam logic [FSM_STATES-1:0] READ_STATE  = {{FSM_STATES-1{1'b0}}, 1'b1};
    // localparam logic [FSM_STATES-1:0] WRITE_STATE = {{FSM_STATES-2{1'b0}}, 1'b1, 1'b0};

    typedef enum {
        RESET_STATE,
        READ_STATE,
        WRITE_STATE
    } fsm_state_t;

    fsm_state_t fsm_state;
    fsm_state_t next_fsm_state;

    // 2D array for natural tree mux insertion
    logic [DATA_WIDTH-1:0] memory [ROWS-1:0][COLS-1:0];

    // Address decode, computed once and shared by the write and read ports
    logic [MEM_ADDRESS-1:0] row;
    logic [MEM_ADDRESS-1:0] col;
    assign row = wr_addr / COLS;
    assign col = wr_addr % COLS;

    // State register
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            fsm_state <= RESET_STATE;
        else
            fsm_state <= next_fsm_state;
    end

    // Next-state logic
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
                        next_fsm_state = READ_STATE; //RESET STATE CAUSES RACE CONDITION
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

    // Write when the FSM is entering WRITE this cycle. Gating on the
    // combinational next state (not the registered fsm_state) aligns the
    // commit with the address/data presented on the same edge, so every
    // write lands and no stray write occurs on the WRITE->READ exit.
    always_ff @(posedge clk) begin
        if ((fsm_state == WRITE_STATE ) && cs) begin
            memory[row][col] <= data_in;
        end
    end

    // Registered read port: data_out is always driven by a flop, so there
    // is no combinational input-to-output path through this module.
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
                    data_out <= memory[row][col];
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
