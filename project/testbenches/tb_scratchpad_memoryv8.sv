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
    begin         \
    `CLK_PERIOD_DEF \
    rw_ = 1'b1;   \
    `CLK_PERIOD_DEF \
    end

`define WRITE     \
    begin         \
    `CLK_PERIOD_DEF \
    rw_ = 1'b0;   \
    `CLK_PERIOD_DEF \
    end


`define RESET_READ_TRANS     \
    begin                    \
        `RESET               \
        `READ                \
    end


`define RESET_WRITE_TRANS    \
    begin                    \
        `RESET               \
        `WRITE               \
    end

`define WRITE_RESET_TRANS    \
    begin                    \
        `WRITE               \
        `RESET               \
    end

`define WRITE_READ_TRANS     \
    begin                    \
        `WRITE               \
        `READ                \
    end

`define READ_RESET_TRANS     \
    begin                    \
        `READ                \
        `RESET               \
    end

`define READ_WRITE_TRANS     \
    begin                    \
        `READ                \
        `WRITE               \
    end

// NOTE:
// In the RTL, cs=0 is the active memory access condition.
// The naming here follows your original macro names, but behavior-wise:
// CS_OFF => cs=0 => selected/active for this DUT.
// CS_ON  => cs=1 => output forced to zero by this DUT.

`define CS_OFF       \
    begin            \
        `CLK_PERIOD_DEF \
        cs = 1'b0;   \
    end

`define CS_ON        \
    begin            \
        `CLK_PERIOD_DEF \
        cs = 1'b1;   \
    end


// Corrected WRITE_TO macro for this DUT:
//
// The DUT writes only when:
//     fsm_state == WRITE_STATE && cs == 0
//
// So the address and data must be stable while the FSM enters WRITE_STATE,
// and then must remain stable for the next clock where the write actually commits.
`define WRITE_TO(addr, data) \
    begin                    \
        cs      = 1'b0;       \
        rw_     = 1'b0;       \
        wr_addr = addr;       \
        data_in = data;       \
        `CLK_PERIOD_DEF       \
        cs      = 1'b0;       \
        rw_     = 1'b0;       \
        wr_addr = addr;       \
        data_in = data;       \
        `CLK_PERIOD_DEF       \
        `CLK_PERIOD_DEF       \
    end


// Corrected READ_FROM macro for this DUT:
//
// The DUT output is registered.
// If coming from WRITE_STATE, one clock is needed to enter READ_STATE,
// and the next clock updates data_out.
`define READ_FROM(addr)      \
    begin                    \
        cs      = 1'b0;       \
        rw_     = 1'b1;       \
        wr_addr = addr;       \
        data_in = '0;         \
        `CLK_PERIOD_DEF       \
        cs      = 1'b0;       \
        rw_     = 1'b1;       \
        wr_addr = addr;       \
        data_in = '0;         \
        `CLK_PERIOD_DEF       \
        `CLK_PERIOD_DEF       \
    end


module tb_scratchpad_memory_v8;

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

    logic [DATA_WIDTH-1:0] read_value;

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
        $dumpvars(0, tb_scratchpad_memory_v8);
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

    task automatic check_equality(
        input logic [DATA_WIDTH-1:0] expected,
        input logic [DATA_WIDTH-1:0] actual,
        input string test_name
    );
        if (expected !== actual)
            test_fail(test_name, $sformatf("Expected: 0x%h Actual: 0x%h", expected, actual));
        else
            test_pass(test_name);
    endtask

    task automatic init_signals;
        begin
            rst     = 1'b1;
            rw_     = 1'b1;
            cs      = 1'b1;
            wr_addr = '0;
            data_in = '0;
            read_value = '0;
            `CLK_PERIOD_DEF;
        end
    endtask

    task automatic reset_dut;
        begin
            rst     = 1'b1;
            rw_     = 1'b1;
            cs      = 1'b1;
            wr_addr = '0;
            data_in = '0;

            `CLK_PERIOD_DEF;
            rst = 1'b0;
            `CLK_PERIOD_DEF;
            rst = 1'b1;
            `CLK_PERIOD_DEF;

            // Put DUT into selected read-idle state after reset.
            cs      = 1'b0;
            rw_     = 1'b1;
            wr_addr = '0;
            data_in = '0;

            `CLK_PERIOD_DEF;
            `CLK_PERIOD_DEF;
        end
    endtask

    task automatic write_mem(
        input logic [MEM_ADDRESS-1:0] addr,
        input logic [DATA_WIDTH-1:0]  data
    );
        begin
            `WRITE_TO(addr, data)
        end
    endtask

    task automatic read_mem(
        input  logic [MEM_ADDRESS-1:0] addr,
        output logic [DATA_WIDTH-1:0]  data
    );
        begin
            `READ_FROM(addr)
            data = data_out;
        end
    endtask

    task automatic selected_idle_read_cycles(input integer cycles);
        integer i;
        begin
            cs      = 1'b0;
            rw_     = 1'b1;
            wr_addr = '0;
            data_in = '0;

            for (i = 0; i < cycles; i = i + 1) begin
                `CLK_PERIOD_DEF;
            end
        end
    endtask

    //================================================================================
    // TESTS
    //================================================================================

    task automatic test_01_reset_output_zero;
        begin
            reset_dut();

            check_equality(
                {DATA_WIDTH{1'b0}},
                data_out,
                "Reset output should be zero"
            );
        end
    endtask

    task automatic test_02_basic_write_read_addr_0;
        begin
            reset_dut();

            write_mem(0, 32'h1234_ABCD);
            read_mem(0, read_value);

            check_equality(
                32'h1234_ABCD,
                read_value,
                "Basic write/read address 0"
            );
        end
    endtask

    task automatic test_03_basic_write_read_addr_10;
        begin
            reset_dut();

            write_mem(10, 32'hA5A5_5A5A);
            read_mem(10, read_value);

            check_equality(
                32'hA5A5_5A5A,
                read_value,
                "Basic write/read address 10"
            );
        end
    endtask

    task automatic test_04_overwrite_same_address;
        begin
            reset_dut();

            write_mem(20, 32'h1111_1111);
            write_mem(20, 32'h2222_2222);
            read_mem(20, read_value);

            check_equality(
                32'h2222_2222,
                read_value,
                "Overwrite same address"
            );
        end
    endtask

    task automatic test_05_multiple_written_addresses;
        begin
            reset_dut();

            write_mem(1, 32'hAAAA_0001);
            write_mem(2, 32'hBBBB_0002);
            write_mem(3, 32'hCCCC_0003);
            write_mem(4, 32'hDDDD_0004);

            read_mem(1, read_value);
            check_equality(32'hAAAA_0001, read_value, "Multiple address read addr 1");

            read_mem(2, read_value);
            check_equality(32'hBBBB_0002, read_value, "Multiple address read addr 2");

            read_mem(3, read_value);
            check_equality(32'hCCCC_0003, read_value, "Multiple address read addr 3");

            read_mem(4, read_value);
            check_equality(32'hDDDD_0004, read_value, "Multiple address read addr 4");
        end
    endtask

    task automatic test_06_cs_high_forces_zero;
        begin
            reset_dut();

            write_mem(5, 32'hFACE_CAFE);
            read_mem(5, read_value);

            check_equality(
                32'hFACE_CAFE,
                read_value,
                "CS active-low selected read before CS high"
            );

            cs      = 1'b1;
            rw_     = 1'b1;
            wr_addr = 5;
            data_in = '0;

            `CLK_PERIOD_DEF;
            `CLK_PERIOD_DEF;

            check_equality(
                {DATA_WIDTH{1'b0}},
                data_out,
                "CS high forces output zero"
            );
        end
    endtask

    task automatic test_07_read_unwritten_after_reset;
        begin
            reset_dut();

            read_mem(0, read_value);

            check_equality(
                {DATA_WIDTH{1'b0}},
                read_value,
                "Read address 0 after reset should be zero"
            );
        end
    endtask

    task automatic test_08_write_then_hold_read_mode;
        begin
            reset_dut();

            write_mem(12, 32'hCAFE_BABE);

            selected_idle_read_cycles(5);

            read_mem(12, read_value);

            check_equality(
                32'hCAFE_BABE,
                read_value,
                "Write then hold read mode"
            );
        end
    endtask

    task automatic test_09_write_read_write_read_same_addr;
        begin
            reset_dut();

            write_mem(25, 32'h0000_0001);
            read_mem(25, read_value);
            check_equality(32'h0000_0001, read_value, "Write/read same addr first value");

            write_mem(25, 32'h0000_0002);
            read_mem(25, read_value);
            check_equality(32'h0000_0002, read_value, "Write/read same addr second value");
        end
    endtask

    task automatic test_10_last_address;
        begin
            reset_dut();

            write_mem(DEPTH-1, 32'h55AA_AA55);
            read_mem(DEPTH-1, read_value);

            check_equality(
                32'h55AA_AA55,
                read_value,
                "Write/read last legal address"
            );
        end
    endtask

    task automatic test_15_last_written_value;
        begin
            reset_dut();

            write_mem(30, 32'h0000_0000);
            write_mem(30, 32'h3333_3333);
            write_mem(30, 32'h6666_6666);
            write_mem(30, 32'h9999_9999);
            write_mem(30, 32'hCCCC_CCCC);

            read_mem(30, read_value);

            check_equality(
                32'hCCCC_CCCC,
                read_value,
                "H5 Last written value address 30"
            );
        end
    endtask

    task automatic test_26_data_persistence;
        begin
            reset_dut();

            write_mem(200, 32'hDEAD_BEEF);

            // Keep cs=0 because cs=1 forces output zero in this RTL.
            cs      = 1'b0;
            rw_     = 1'b1;
            wr_addr = 200;
            data_in = '0;

            `CLK_PERIOD_DEF;
            `CLK_PERIOD_DEF;
            `CLK_PERIOD_DEF;
            `CLK_PERIOD_DEF;
            `CLK_PERIOD_DEF;

            read_mem(200, read_value);

            check_equality(
                32'hDEAD_BEEF,
                read_value,
                "EX6 Data persistence address 200"
            );
        end
    endtask

    //================================================================================
    // MAIN
    //================================================================================

    initial begin
        init_signals();

        $display("============================================================");
        $display("Starting tb_scratchpad_memory_v8");
        $display("DATA_WIDTH  = %0d", DATA_WIDTH);
        $display("ROWS        = %0d", ROWS);
        $display("COLS        = %0d", COLS);
        $display("DEPTH       = %0d", DEPTH);
        $display("MEM_ADDRESS = %0d", MEM_ADDRESS);
        $display("============================================================");

        test_01_reset_output_zero();
        test_02_basic_write_read_addr_0();
        test_03_basic_write_read_addr_10();
        test_04_overwrite_same_address();
        test_05_multiple_written_addresses();
        test_06_cs_high_forces_zero();
        test_07_read_unwritten_after_reset();
        test_08_write_then_hold_read_mode();
        test_09_write_read_write_read_same_addr();
        test_10_last_address();

        test_15_last_written_value();
        test_26_data_persistence();

        $display("============================================================");
        $display("Simulation complete");
        $display("Total tests : %0d", test_count);
        $display("Passed      : %0d", pass_count);
        $display("Failed      : %0d", fail_count);
        $display("============================================================");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED");
        end
        else begin
            $display("SOME TESTS FAILED");
        end

        $finish;
    end

endmodule