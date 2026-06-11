
`include "nar_params.vh"



module scratchpad_memory #(
    parameter DATA_WIDTH      = NAR_NUM_BITS,
    parameter ROWS            = NAR_MAT_ROWS,
    parameter COLS            = NAR_MAT_COLS,
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

    //  parameter MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP
    //the above param got removed, due to linter warnings




    // localparam DEPTH = ROWS * COLS;
    //the above param got removed, due to linter warnings

    //definitions of ZERO and ONE
    localparam logic [DATA_WIDTH-1:0] MEM_ZERO = {DATA_WIDTH{1'b0}};
    localparam logic [DATA_WIDTH-1:0] MEM_ONE = {DATA_WIDTH{1'b1}};
    localparam int FSM_STATES = 3;

    localparam logic [FSM_STATES-1:0] RESET_STATE = {FSM_STATES{1'b0}};
    localparam logic [FSM_STATES-1:0] READ_STATE  = {{FSM_STATES-1{1'b0}}, 1'b1};
    localparam logic [FSM_STATES-1:0] WRITE_STATE = {{FSM_STATES-2{1'b0}}, 1'b1, 1'b0};

    logic [FSM_STATES-1:0] fsm_state;
    logic [FSM_STATES-1:0] next_fsm_state;
    // logic write_done; //FSM LOGIC, TO AVOID READ AGAIN WITHOUT WRITING

    // assign next_fsm_state = fsm_state;

    // logic [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    // using 2D array for natural tree mux insertion
    logic [ DATA_WIDTH - 1 : 0 ] memory [ ROWS - 1 : 0 ][ COLS - 1 : 0 ];



    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            fsm_state <= RESET_STATE;
            // write_done <= 1'b0;
        end
        else begin
            fsm_state <= next_fsm_state;
            // // Set write_done flag when entering WRITE_STATE
            // if (next_fsm_state == WRITE_STATE) begin
            //     write_done <= 1'b1;
            // end
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

    // Write when the FSM is entering WRITE this cycle. Gating on the
    // combinational next state (not the registered fsm_state) aligns the
    // commit with the address/data presented on the same edge, so every
    // write lands and no stray write occurs on the WRITE->READ exit.
    always_ff @(posedge clk) begin
        if (next_fsm_state == WRITE_STATE) begin
            memory [ wr_addr / COLS ][ wr_addr % COLS ] <= data_in;
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
                    data_out <= memory [ wr_addr / COLS ] [ wr_addr % COLS ];
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














// module buffer_out #(
//     parameter DATA_WIDTH      = NAR_NUM_BITS
// )
// (


//     input  logic [DATA_WIDTH-1:0] data_in_buffer,

//     input logic cs,

//     output logic [DATA_WIDTH-1:0] data_out_buffer
// );
//     bufif1 (data_out_buffer, data_in_buffer, cs);

// endmodule


// module scratchpad_memory #(
//     parameter DATA_WIDTH      = NAR_NUM_BITS,
//     parameter ROWS            = NAR_MAT_ROWS,
//     parameter COLS            = NAR_MAT_COLS,
//     parameter MAX_INPUT_SCOOP = NAR_MAX_INPUT_SCOOP,
//     parameter MEM_ADDRESS     = $clog2(NAR_MAT_ROWS * NAR_MAT_COLS)
// )
// (
//     input  logic clk,      // Clock
//     input  logic rw_,      // 0 = Write, 1 = Read
//     input  logic cs,       // chip select
//     input  logic rst,      // reset

//     input  logic [MEM_ADDRESS-1:0] wr_addr,

//     input  logic [DATA_WIDTH-1:0] data_in,

//     output logic [DATA_WIDTH-1:0] data_out
// );



// endmodule





























endmodule


