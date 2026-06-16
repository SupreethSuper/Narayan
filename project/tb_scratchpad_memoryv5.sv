`timescale 1ns/1ps
`include "nar_params.vh"


`define CLK_PERIOD_DEF        \
    begin                     \
    @(posedge clk);           \
    @(negedge clk);           \
    end

// Assert active-low reset for one clock cycle then release
`define RESET       \
    begin           \
    `CLK_PERIOD_DEF \
    rst = 1'b0;     \
    `CLK_PERIOD_DEF \
    rst = 1'b1;     \
    `CLK_PERIOD_DEF \
    end


`define READ      \
    begin           \
    `CLK_PERIOD_DEF \
    rw_ = 1'b1;     \
    `CLK_PERIOD_DEF \
    end

`define WRITE     \
    begin           \
    `CLK_PERIOD_DEF \
    rw_ = 1'b0;     \
    `CLK_PERIOD_DEF \
    end


`define RESET_READ_TRANS     \
    begin                    \
        `RESET               \
        `READ                \
    end                    


`define RESET_WRITE_TRANS     \
    begin                    \
        `RESET               \
        `WRITE               \
    end   

`define WRITE_RESET_TRANS     \
    begin                    \
        `WRITE               \
        `RESET               \
    end         

`define WRITE_READ_TRANS    \
    begin                    \
        `WRITE               \
        `READ                \
    end

`define READ_RESET_TRANS    \
    begin                    \
        `READ                \
        `RESET               \
    end

`define READ_WRITE_TRANS    \
    begin                    \
        `READ                \
        `WRITE               \
    end

`define CS_OFF    \
    begin            \
        `CLK_PERIOD_DEF \
        cs = 1'b0;     \
    end

`define CS_ON    \
    begin            \
        `CLK_PERIOD_DEF \
        cs = 1'b1;     \
    end


`define WRITE_TO(addr, data) \
    begin \
        `CLK_PERIOD_DEF \
        `WRITE          \
        wr_addr = addr; \
        `CLK_PERIOD_DEF \
        data_in = data; \
        `CLK_PERIOD_DEF \
    end

`define READ_FROM(addr) \
    begin \
        `CLK_PERIOD_DEF \
        `READ         \
        wr_addr = addr; \
        `CLK_PERIOD_DEF \
    end


module tb_scratchpad_memory_v5;

    //================================================================================
    // PARAMETERS
    //================================================================================

    localparam DATA_WIDTH  = NAR_NUM_BITS;
    localparam ROWS        = NAR_MAT_ROWS;
    localparam COLS        = NAR_MAT_COLS;
    localparam MEM_ADDRESS = $clog2(ROWS * COLS);
    localparam DEPTH       = ROWS * COLS;
    localparam CLK_PERIOD  = 10;

    //================================================================================
    // TEST SIGNALS
    //================================================================================

    logic clk;
    logic rst;
    logic rw_;
    logic cs;
    logic [MEM_ADDRESS-1:0] wr_addr;
    logic [DATA_WIDTH-1:0]  data_in;
    logic [DATA_WIDTH-1:0]  data_out;

    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;

    //================================================================================
    // DUT
    //================================================================================

    scratchpad_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ROWS       (ROWS),
        .COLS       (COLS),
        .MEM_ADDRESS(MEM_ADDRESS)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .rw_     (rw_),
        .cs      (cs),
        .wr_addr (wr_addr),
        .data_in (data_in),
        .data_out(data_out)
    );

    //================================================================================
    // CLOCK
    //================================================================================

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //================================================================================
    // WAVEFORMS
    //================================================================================

    initial begin
        $dumpfile("tb_scratchpad_memory.vcd");
        $dumpvars(0, tb_scratchpad_memory_v5);
    end

    //================================================================================
    // TASKS
    //================================================================================

    task automatic test_pass(string test_name);
        pass_count++;
        test_count++;
        $display("[PASS] Test %3d: %s", test_count, test_name);
    endtask

    task automatic test_fail(string test_name, string reason);
        fail_count++;
        test_count++;
        $display("[FAIL] Test %3d: %s | Reason: %s", test_count, test_name, reason);
    endtask

    task automatic check_equality(logic [DATA_WIDTH-1:0] expected, logic [DATA_WIDTH-1:0] actual, string test_name);
        if (expected != actual)
            test_fail(test_name, $sformatf("Expected: 0x%h Actual: 0x%h", expected, actual));
        else
            test_pass(test_name);
    endtask



    //========================================================================================
    // ACTUAL TESTS
    //=========================================================================================

    initial begin

        //======================================================================================
        // TEST INVOLVING RESETS
        //=======================================================================================
        

        //RESERT -> CS_ON -> TRY TO WRITE -> READ FROM THAT
        `RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'd0, 32'hDEAD0000)
        `WRITE_TO(5'd6, 32'h0000_BEEF)
        `WRITE_READ_TRANS
        `READ_FROM(5'd1)
        check_equality(32'h0000_0000, data_out, "Test 1: Write then Read after reset with CS ON");

        `READ_FROM(5'd5)
        check_equality(32'h0000_0000, data_out, "Test 1: Write then Read after reset with CS ON");

        //RESERT -> CS_OFF -> TRY TO WRITE -> READ FROM THAT
        `RESET
        `CS_OFF
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h15, 32'hDEADBEEF)
        `WRITE_READ_TRANS
        `READ_FROM(5'h15)
        check_equality(32'h0000_0000, data_out, "Test 2: Write then Read after reset with CS OFF");

        //RESERT -> CS_ON -> TRY TO WRITE to 5'h15 -> READ FROM 5'h10
        `RESET
        `CS_ON
        `RESET_WRITE_TRANS
        `WRITE_TO(5'h15, 32'hFACA_CACA)
        `WRITE_READ_TRANS
        `READ_FROM(5'h10)
        check_equality(32'h0000_0000, data_out, "Test 3: Read from other location");

        //RESET -> CS_ON -> TRY TO READ FROM A LOC -> WRITE TO THAT LOC -> READ FROM THAT LOC AGAIN
        `RESET
        `CS_ON
        `RESET_READ_TRANS
        `READ_FROM(5'h15)
        check_equality(32'h0000_0000, data_out, "Test 4A: Read from location 5'h15 before write");
        `READ_WRITE_TRANS
        `WRITE_TO(5'h15, 32'hC33C_C33C)
        `WRITE_READ_TRANS
        `READ_FROM(5'h15)
        check_equality(32'hC33C_C33C, data_out, "Test 4B: Read from location 5'h15 after write");





        `CLK_PERIOD_DEF
        $finish;

        
    end

endmodule
