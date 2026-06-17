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

    typedef enum {
        RESET_STATE,
        READ_STATE,
        WRITE_STATE
    } fsm_state_t;

    fsm_state_t fsm_state;
    fsm_state_t next_fsm_state;

    // Data store (not reset — its contents are masked by cell_valid below).
    logic [DATA_WIDTH-1:0] memory [ROWS-1:0][COLS-1:0];

    // Per-cell valid flags, PACKED so the whole thing clears in one shot on
    // reset. This is the key: reset drives ONE small (ROWS*COLS-bit) register,
    // NOT a per-element loop over the 800-bit memory — so the reset net stays
    // tiny and the slew is unaffected. A cell reads back its data only if its
    // own valid bit is set (per-cell => no row/col aliasing); reset clears all
    // valid bits => no stale-data resurrection after a later write.
    logic [ROWS*COLS-1:0] cell_valid;

    // Address decode, shared by the write and read ports
    logic [MEM_ADDRESS-1:0] row;
    logic [MEM_ADDRESS-1:0] col;
    assign row = wr_addr / COLS;
    assign col = wr_addr % COLS;

    // State register (active-low async reset)
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            fsm_state <= RESET_STATE;
        else
            fsm_state <= next_fsm_state;
    end

    // Next-state logic (pure: no side-effect signals, no inferred latches)
    always_comb begin
        next_fsm_state = fsm_state;

        if (!cs) begin
            next_fsm_state = READ_STATE;
        end
        else begin
            case (fsm_state)
                RESET_STATE: begin
<<<<<<< HEAD
                    if (!rw_)
                        next_fsm_state = WRITE_STATE;
                    else
                        next_fsm_state = RESET_STATE;
                    // next_fsm_state = RESET_STATE || WRITE_STATE;
=======
                    if (!rw_) next_fsm_state = WRITE_STATE;
                    else      next_fsm_state = READ_STATE;
>>>>>>> main
                end
                READ_STATE: begin
                    if (rw_)  next_fsm_state = READ_STATE;
                    else      next_fsm_state = WRITE_STATE;
                end
                WRITE_STATE: begin
                    if (rw_)  next_fsm_state = READ_STATE;
                    else      next_fsm_state = WRITE_STATE;
                end
                default: next_fsm_state = RESET_STATE;
            endcase
        end
    end

    // Valid flags: async-cleared as a single packed register (no loop, small
    // reset fan-out), then set one bit per committed write. Out-of-range
    // addresses (row >= ROWS) target a non-existent element and are ignored.
    always_ff @(posedge clk or negedge rst) begin
        if (!rst)
            cell_valid <= { {(ROWS*COLS){1'b0}} };
        else if ((fsm_state == WRITE_STATE) && cs)
            cell_valid[wr_addr] <= 1'b1;
    end

    // Data write port (no reset on the data array itself).
    always_ff @(posedge clk) begin
        if ((fsm_state == WRITE_STATE) && cs)
            memory[row][col] <= data_in;
    end

    // Registered read port: data_out is always driven by a flop (no comb
    // input->output path). A cell returns its data only when its valid bit is
    // set, else MEM_ZERO. Out-of-range reads index a non-existent valid bit
    // (X), so the gate falls through to MEM_ZERO.
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
                    if (cell_valid[wr_addr])
                        data_out <= memory[row][col];
                    else
                        data_out <= MEM_ZERO;
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
