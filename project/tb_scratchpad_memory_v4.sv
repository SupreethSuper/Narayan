`include "nar_params.vh"
`timescale 1ns/1ps
//==============================================================================
// tb_scratchpad_memory_v4.sv
//
// Self-checking testbench for scratchpad_memory.sv.
//
// Verification model: the DUT is treated as an IDEAL synchronous RAM.
//   * A write driven with (cs=1, rw_=0, wr_addr=A, data_in=D) stores D at A.
//   * A read driven with (cs=1, rw_=1, wr_addr=A) returns the last value
//     stored at A, RD_LATENCY clock edges later.
//   * Reset / chip-deselect force data_out to 0.
//
// Every operation is checked against an in-TB reference memory (scoreboard).
// There are NO unconditional "test_pass" calls: a test can only pass by
// matching the reference. If the RTL deviates from ideal-RAM behaviour the
// mismatch is reported as a real [FAIL] with expected vs actual values.
//
// RD_LATENCY is the number of posedges, after the read address/strobe are
// presented, at which data_out is expected to be valid. It matches the DUT's
// registered read path (enter READ state -> registered memory read).
//==============================================================================
module tb_scratchpad_memory_v4;

    //--------------------------------------------------------------------------
    // Parameters (sourced from headers so TB tracks the design)
    //--------------------------------------------------------------------------
    localparam int DATA_WIDTH  = NAR_NUM_BITS;
    localparam int ROWS        = NAR_MAT_ROWS;
    localparam int COLS        = NAR_MAT_COLS;
    localparam int DEPTH       = ROWS * COLS;
    localparam int MEM_ADDRESS = $clog2(ROWS * COLS);
    localparam int CLK_PERIOD  = 10;
    localparam int RD_LATENCY  = 2;     // posedges from read-address presented -> data_out valid
    localparam int RAND_OPS    = 60;    // randomized write/read operations

    //--------------------------------------------------------------------------
    // DUT interface signals
    //--------------------------------------------------------------------------
    logic                    clk, rst, rw_, cs;
    logic [MEM_ADDRESS-1:0]  wr_addr;
    logic [DATA_WIDTH-1:0]   data_in, data_out;

    //--------------------------------------------------------------------------
    // Scoreboard (golden reference memory) and bookkeeping
    //--------------------------------------------------------------------------
    logic [DATA_WIDTH-1:0] ref_mem [int];   // address -> expected data
    integer test_count = 0, pass_count = 0, fail_count = 0;

    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------
    scratchpad_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .ROWS       (ROWS),
        .COLS       (COLS),
        .MEM_ADDRESS(MEM_ADDRESS)
    ) dut (
        .clk(clk), .rst(rst), .rw_(rw_), .cs(cs),
        .wr_addr(wr_addr), .data_in(data_in), .data_out(data_out)
    );

    //--------------------------------------------------------------------------
    // Clock
    //--------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //--------------------------------------------------------------------------
    // Core check primitive
    //--------------------------------------------------------------------------
    task automatic check(input logic [DATA_WIDTH-1:0] got,
                         input logic [DATA_WIDTH-1:0] exp,
                         input string name);
        test_count++;
        if (got === exp) begin
            pass_count++;
            $display("[PASS] %3d  %-40s exp=0x%08h got=0x%08h", test_count, name, exp, got);
        end
        else begin
            fail_count++;
            $display("[FAIL] %3d  %-40s exp=0x%08h got=0x%08h", test_count, name, exp, got);
        end
    endtask

    //--------------------------------------------------------------------------
    // Bus operations. Stimulus is driven on negedge so all setup happens away
    // from the active (posedge) edge that the DUT samples.
    //--------------------------------------------------------------------------

    // Reset sequence; leaves the part selected and idle (cs=1, rw_=1).
    task automatic apply_reset();
        @(negedge clk);
        rst = 1'b0; cs = 1'b0; rw_ = 1'b1; wr_addr = '0; data_in = '0;
        repeat (3) @(negedge clk);
        rst = 1'b1; cs = 1'b1;
        @(negedge clk);
    endtask

    // Ideal write: present (A,D) for one clock; update scoreboard.
    task automatic mem_write(input int a, input logic [DATA_WIDTH-1:0] d);
        @(negedge clk);
        cs      = 1'b1;
        rw_     = 1'b0;
        wr_addr = MEM_ADDRESS'(a);
        data_in = d;
        @(posedge clk);          // value sampled here by an ideal RAM
        ref_mem[a] = d;          // golden model commits the write
    endtask

    // Ideal read-and-check: present (A, read) and sample data_out RD_LATENCY
    // posedges later; compare against scoreboard.
    task automatic mem_read_check(input int a, input string name);
        logic [DATA_WIDTH-1:0] exp;
        exp = ref_mem[a];
        @(negedge clk);
        cs      = 1'b1;
        rw_     = 1'b1;
        wr_addr = MEM_ADDRESS'(a);
        repeat (RD_LATENCY) @(posedge clk);
        #1;                      // let nonblocking updates settle
        check(data_out, exp, name);
    endtask

    // Sample data_out now and compare to a literal expectation.
    task automatic expect_out(input logic [DATA_WIDTH-1:0] exp, input string name);
        #1;
        check(data_out, exp, name);
    endtask

    //--------------------------------------------------------------------------
    // Test program
    //--------------------------------------------------------------------------
    int          addr_list [$];   // addresses touched by the random phase
    bit          seen      [int]; // dedup helper
    int          a;
    logic [DATA_WIDTH-1:0] d;

    initial begin
        $dumpfile("tb_scratchpad_memory_v4.vcd");
        $dumpvars(0, tb_scratchpad_memory_v4);

        $display("==================================================================");
        $display(" scratchpad_memory self-checking TB (golden ideal-RAM model)");
        $display(" DATA_WIDTH=%0d  DEPTH=%0d  MEM_ADDRESS=%0d  RD_LATENCY=%0d",
                 DATA_WIDTH, DEPTH, MEM_ADDRESS, RD_LATENCY);
        $display("==================================================================");

        //----------------------------------------------------------------------
        // 1. Reset and chip-select control
        //----------------------------------------------------------------------
        $display("\n-- Section 1: reset / chip-select --------------------------------");
        apply_reset();
        expect_out('0, "S1.1 data_out==0 after reset");

        // Deselect must force data_out to 0.
        @(negedge clk); cs = 1'b0;
        repeat (2) @(posedge clk);
        expect_out('0, "S1.2 data_out==0 while cs deasserted");
        @(negedge clk); cs = 1'b1;

        //----------------------------------------------------------------------
        // 2. Single write / read-back, various data patterns
        //----------------------------------------------------------------------
        $display("\n-- Section 2: single write / read-back ---------------------------");
        begin
            // addresses derived from DEPTH so the TB is valid at any size
            int        pa   [] = '{0, 1, DEPTH/8, DEPTH/2, DEPTH-1};
            logic [31:0] pd [] = '{32'h00000000, 32'hFFFFFFFF, 32'hAAAAAAAA,
                                   32'h55555555, 32'hDEADBEEF};
            foreach (pa[i]) begin
                mem_write(pa[i], pd[i]);
                mem_read_check(pa[i], $sformatf("S2.%0d single rw addr %0d", i+1, pa[i]));
            end
        end

        //----------------------------------------------------------------------
        // 3. Burst of writes, then burst of reads
        //----------------------------------------------------------------------
        $display("\n-- Section 3: write burst then read burst ------------------------");
        for (int i = 0; i < 8; i++)
            mem_write(DEPTH/4 + i, 32'hC0DE0000 + i);
        for (int i = 0; i < 8; i++)
            mem_read_check(DEPTH/4 + i,
                           $sformatf("S3.%0d burst read addr %0d", i+1, DEPTH/4 + i));

        //----------------------------------------------------------------------
        // 4. Overwrite (last write wins)
        //----------------------------------------------------------------------
        $display("\n-- Section 4: overwrite ------------------------------------------");
        mem_write(DEPTH/3, 32'h11112222);
        mem_write(DEPTH/3, 32'h33334444);
        mem_read_check(DEPTH/3, "S4.1 overwrite: last value wins");

        //----------------------------------------------------------------------
        // 5. Full address-range coverage (low / mid / high within 0..DEPTH-1)
        //----------------------------------------------------------------------
        $display("\n-- Section 5: address-range coverage -----------------------------");
        begin
            int ra [] = '{0, 1, DEPTH/4, DEPTH/2, (3*DEPTH)/4, DEPTH-1};
            foreach (ra[i])
                mem_write(ra[i], 32'hA5A50000 + ra[i]);
            foreach (ra[i])
                mem_read_check(ra[i], $sformatf("S5.%0d hi-addr %0d", i+1, ra[i]));
        end

        //----------------------------------------------------------------------
        // 6. Randomized writes with scoreboard read-back
        //----------------------------------------------------------------------
        $display("\n-- Section 6: randomized read/write ------------------------------");
        addr_list.delete();
        seen.delete();
        for (int k = 0; k < RAND_OPS; k++) begin
            a = $urandom_range(0, DEPTH-1);
            d = $urandom;
            mem_write(a, d);
            if (!seen.exists(a)) begin
                seen[a] = 1'b1;
                addr_list.push_back(a);
            end
        end
        foreach (addr_list[i])
            mem_read_check(addr_list[i],
                           $sformatf("S6.%0d rand addr %0d", i+1, addr_list[i]));

        //----------------------------------------------------------------------
        // 7. Asynchronous reset clears the output
        //----------------------------------------------------------------------
        $display("\n-- Section 7: async reset clears output --------------------------");
        mem_write(DEPTH-1, 32'hFACEFACE);
        @(negedge clk); rst = 1'b0;
        repeat (2) @(posedge clk);
        expect_out('0, "S7.1 data_out==0 during reset");
        @(negedge clk); rst = 1'b1;
        // The FSM leaves RESET only via a write, so prime it with a scratch
        // write before reading (a read straight out of RESET never engages).
        mem_write(DEPTH-2, 32'h0000ABCD);
        // value written before reset must survive the reset
        mem_read_check(DEPTH-1, "S7.2 data survives reset");

        //----------------------------------------------------------------------
        // Summary
        //----------------------------------------------------------------------
        @(posedge clk);
        $display("\n==================================================================");
        $display(" SUMMARY:  total=%0d  pass=%0d  fail=%0d  (%0d%% pass)",
                 test_count, pass_count, fail_count,
                 (test_count == 0) ? 0 : (pass_count * 100) / test_count);
        if (fail_count == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: %0d TEST(S) FAILED", fail_count);
        $display("==================================================================");
        $finish;
    end

    //--------------------------------------------------------------------------
    // Watchdog
    //--------------------------------------------------------------------------
    initial begin
        #(5000 * CLK_PERIOD);
        $display("[FATAL] watchdog timeout");
        $finish;
    end

endmodule
