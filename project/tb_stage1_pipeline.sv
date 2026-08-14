`include "nar_params.vh"
`include "scheduler_params.vh"
`timescale 1ns/1ps

module tb_stage1_pipeline();

    localparam DATA_WIDTH = NAR_NUM_BITS;
    localparam NUM_UNITS  = SCHED_MEM_UNITS;

    // ---- DUT inputs ----
    logic                  tb_clk;
    logic                  tb_rw_;
    logic                  tb_rst;
    logic                  tb_cs;
    logic                  tb_next;
    logic [DATA_WIDTH-1:0] tb_data_in;

    // ---- DUT outputs: memory taps ----
    logic [DATA_WIDTH-1:0] tb_mem1_out;
    logic [DATA_WIDTH-1:0] tb_mem2_out;
    logic [DATA_WIDTH-1:0] tb_mem3_out;
    logic [DATA_WIDTH-1:0] tb_mem4_out;

    // ---- DUT outputs: pipeline1 stage ----
    logic                  tb_pipe1_clk;
    logic                  tb_pipe1_rst;
    logic                  tb_pipe1_cs;
    logic [DATA_WIDTH-1:0] tb_pipe1_mem1_out;
    logic [DATA_WIDTH-1:0] tb_pipe1_mem2_out;
    logic [DATA_WIDTH-1:0] tb_pipe1_mem3_out;
    logic [DATA_WIDTH-1:0] tb_pipe1_mem4_out;

    stage1_pipeline #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_UNITS(NUM_UNITS)
    ) uut(
        .clk(tb_clk),
        .rw_(tb_rw_),
        .rst(tb_rst),
        .cs(tb_cs),
        .next(tb_next),
        .data_in(tb_data_in),
        .mem1_out(tb_mem1_out),
        .mem2_out(tb_mem2_out),
        .mem3_out(tb_mem3_out),
        .mem4_out(tb_mem4_out),
        .pipe1_clk(tb_pipe1_clk),
        .pipe1_rst(tb_pipe1_rst),
        .pipe1_cs(tb_pipe1_cs),
        .pipe1_mem1_out(tb_pipe1_mem1_out),
        .pipe1_mem2_out(tb_pipe1_mem2_out),
        .pipe1_mem3_out(tb_pipe1_mem3_out),
        .pipe1_mem4_out(tb_pipe1_mem4_out)
    );


    integer errors = 0;


    always begin : clk_gen
        #1 tb_clk = ~tb_clk;
    end


    initial begin : wave_gen
        $dumpfile("stage1_pipeline_waves.vcd");
        $dumpvars(0, tb_stage1_pipeline);
    end


    //testplan
    //1. reset the pulse, once with the cs = 1, and once with cs = 0
    //2. put the reset high for cs = 1 for 2 clock high, and bring it back to low
    //3. bring back to ideal operating limits. Write values into memory and
    //   confirm the pipeline mirrors mem1_out, and so on
    //4. test all the stimuli under cs = 0
    //5. end the simulation with $finish

    //---------------display style--------------------
    //1. use $display to display the values of the signals
    //2. use $strobe to display the values of the signals
    //3. use $finish to end the simulation
    //4. Use the format "time, signal name, value of the signal"

    //-------------delay----------------------
    //1. do not use "#" delay
    //2. use "@ posedge" and "@ negedge" clock for the delay
    //3. After the signal is set, use wait, so as to set the signal, then use @ to settle

    //--------------checks------------------
    //1. use tasks to check the outputs of the dut with the expected values


    // ----------------------------------------------------------------
    // check_pass_through
    // pipeline1 forwards the top-level clk/rst/cs and the four memory
    // outputs combinationally, so every pipe1_* output must equal what
    // it mirrors at the moment of the check. Comparing pipe1_memN
    // against the DUT's own memN_out keeps the check valid regardless
    // of the exact scheduler beat timing. Any mismatch is counted in
    // `errors`.
    // ----------------------------------------------------------------
    task automatic check_pass_through(input string tag);
        logic ok;
        ok = 1'b1;

        if (tb_pipe1_clk !== tb_clk) begin
            ok = 1'b0; errors = errors + 1;
            $display("time=%0t, pipe1_clk, got=%b exp=%b  [FAIL - %s]", $time, tb_pipe1_clk, tb_clk, tag);
        end
        if (tb_pipe1_rst !== tb_rst) begin
            ok = 1'b0; errors = errors + 1;
            $display("time=%0t, pipe1_rst, got=%b exp=%b  [FAIL - %s]", $time, tb_pipe1_rst, tb_rst, tag);
        end
        if (tb_pipe1_cs !== tb_cs) begin
            ok = 1'b0; errors = errors + 1;
            $display("time=%0t, pipe1_cs, got=%b exp=%b  [FAIL - %s]", $time, tb_pipe1_cs, tb_cs, tag);
        end
        if (tb_pipe1_mem1_out !== tb_mem1_out) begin
            ok = 1'b0; errors = errors + 1;
            $display("time=%0t, pipe1_mem1_out, got=%h exp=%h  [FAIL - %s]", $time, tb_pipe1_mem1_out, tb_mem1_out, tag);
        end
        if (tb_pipe1_mem2_out !== tb_mem2_out) begin
            ok = 1'b0; errors = errors + 1;
            $display("time=%0t, pipe1_mem2_out, got=%h exp=%h  [FAIL - %s]", $time, tb_pipe1_mem2_out, tb_mem2_out, tag);
        end
        if (tb_pipe1_mem3_out !== tb_mem3_out) begin
            ok = 1'b0; errors = errors + 1;
            $display("time=%0t, pipe1_mem3_out, got=%h exp=%h  [FAIL - %s]", $time, tb_pipe1_mem3_out, tb_mem3_out, tag);
        end
        if (tb_pipe1_mem4_out !== tb_mem4_out) begin
            ok = 1'b0; errors = errors + 1;
            $display("time=%0t, pipe1_mem4_out, got=%h exp=%h  [FAIL - %s]", $time, tb_pipe1_mem4_out, tb_mem4_out, tag);
        end

        if (ok)
            $display("time=%0t, check, PASS - %s", $time, tag);
    endtask


    // ----------------------------------------------------------------
    // print_state
    // Dumps the settled memory/pipeline snapshot with $strobe (end of
    // the current timestep) in "time, signal name, value" style.
    // ----------------------------------------------------------------
    task automatic print_state(input string tag);
        $strobe("time=%0t, state[%s], rst=%b cs=%b | mem  mem1=%h mem2=%h mem3=%h mem4=%h",
                 $time, tag, tb_rst, tb_cs, tb_mem1_out, tb_mem2_out, tb_mem3_out, tb_mem4_out);
        $strobe("time=%0t, state[%s], pipe1_rst=%b pipe1_cs=%b | pipe mem1=%h mem2=%h mem3=%h mem4=%h",
                 $time, tag, tb_pipe1_rst, tb_pipe1_cs,
                 tb_pipe1_mem1_out, tb_pipe1_mem2_out, tb_pipe1_mem3_out, tb_pipe1_mem4_out);
    endtask


    // ----------------------------------------------------------------
    // step_addr
    // Pulses `next` high for one cycle then low for one cycle so the
    // scheduler's edge detector sees exactly one rising edge and
    // advances the address by one beat (same helper as tb_narayan_bdf).
    // ----------------------------------------------------------------
    task automatic step_addr();
        tb_next = 1'b1;
        @(posedge tb_pipe1_clk);
        tb_next = 1'b0;
        @(posedge tb_pipe1_clk);
    endtask


    initial begin : test_stimulus

        // clk_gen delays #1 before its first toggle, so initializing
        // here at time 0 wins the race and gives a clean clock.
        tb_clk = 1'b0;

        // ideal quiescent inputs
        tb_rw_     = 1'b1;   // read (not writing)
        tb_rst     = 1'b0;
        tb_cs      = 1'b0;
        tb_next    = 1'b0;
        tb_data_in = '0;
        $display("time=%0t, INFO, tb_stage1_pipeline start", $time);

        // ============================================================
        // 1. reset pulse, once with cs = 1, once with cs = 0
        // ============================================================
        tb_cs  = 1'b1;
        tb_rst = 1'b1;
        wait (tb_cs === 1'b1 && tb_rst === 1'b1);
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        print_state("rst pulse, cs=1");
        check_pass_through("rst pulse, cs=1");

        tb_rst = 1'b0;
        wait (tb_rst === 1'b0);
        @(posedge tb_pipe1_clk);
        check_pass_through("rst deassert, cs=1");

        tb_cs  = 1'b0;
        tb_rst = 1'b1;
        wait (tb_cs === 1'b0 && tb_rst === 1'b1);
        @(posedge tb_pipe1_clk);
        print_state("rst pulse, cs=0");
        check_pass_through("rst pulse, cs=0");

        tb_rst = 1'b0;
        wait (tb_rst === 1'b0);
        @(posedge tb_pipe1_clk);
        check_pass_through("rst deassert, cs=0");

        // ============================================================
        // 2. reset high for cs = 1 for 2 clock highs, then bring low
        // ============================================================
        tb_cs  = 1'b1;
        tb_rst = 1'b1;
        wait (tb_cs === 1'b1 && tb_rst === 1'b1);
        @(posedge tb_pipe1_clk);
        check_pass_through("rst hold, clk high 1");
        @(posedge tb_pipe1_clk);
        check_pass_through("rst hold, clk high 2");

        tb_rst = 1'b0;
        wait (tb_rst === 1'b0);
        @(posedge tb_pipe1_clk);
        check_pass_through("rst released after 2 highs");

        // ============================================================
        // 3. ideal operating limits: write a DISTINCT value into
        //    address 0 of each of the four memories, then read them all
        //    back together. On read the scheduler selects every memory
        //    at the same shared address, so mem1..mem4 present four
        //    distinct non-zero values simultaneously -- this gives the
        //    pipe1_memN === memN check real teeth (it can now catch a
        //    lane swap, not merely all-zeros).
        //
        //    Beat map (each `next` advances beat_cnt by one): address 0
        //    of mem1/mem2/mem3/mem4 sits at beat_cnt 0/5/10/15.
        //
        //    NOTE: rst is active-low -- tb_rst=1 DEASSERTS reset (normal
        //    operation). It must stay 1 the whole phase or the memories
        //    sit in RESET_STATE and no write ever commits.
        // ============================================================
        tb_rst     = 1'b1;             // deassert reset (active-low)
        tb_cs      = 1'b1;
        tb_rw_     = 1'b0;             // write mode
        tb_data_in = 32'h1111_0001;    // V1 -> mem1[0]
        wait (tb_cs === 1'b1 && tb_rst === 1'b1 && tb_rw_ === 1'b0);
        @(posedge tb_pipe1_clk);       // beat0: mem1 FSM RESET->WRITE (first-write latency)
        @(posedge tb_pipe1_clk);       // beat0: do_write commits mem1[0]=V1
        check_pass_through("write mem1[0]=V1 (beat0)");

        // advance beat0 -> beat5 (mem2, addr0), then commit V2
        for (int k = 0; k < 5; k++) step_addr();
        tb_data_in = 32'h2222_0002;    // V2 -> mem2[0]
        @(posedge tb_pipe1_clk);
        check_pass_through("write mem2[0]=V2 (beat5)");

        // advance beat5 -> beat10 (mem3, addr0), then commit V3
        for (int k = 0; k < 5; k++) step_addr();
        tb_data_in = 32'h3333_0003;    // V3 -> mem3[0]
        @(posedge tb_pipe1_clk);
        check_pass_through("write mem3[0]=V3 (beat10)");

        // advance beat10 -> beat15 (mem4, addr0), then commit V4
        for (int k = 0; k < 5; k++) step_addr();
        tb_data_in = 32'h4444_0004;    // V4 -> mem4[0]
        @(posedge tb_pipe1_clk);
        check_pass_through("write mem4[0]=V4 (beat15)");

        // read back all four lanes together: rw_=1 selects every memory
        // and beat_cnt stays at 15 (addr 0), so the four distinct values
        // appear on mem1..mem4 (and therefore pipe1_mem1..4) at once.
        tb_rw_ = 1'b1;
        wait (tb_rw_ === 1'b1);
        @(posedge tb_pipe1_clk);       // fsm -> READ
        @(posedge tb_pipe1_clk);       // data_out registers memory[0][0] per lane
        @(posedge tb_pipe1_clk);       // extra settle
        print_state("readback mem[0], all lanes distinct, cs=1");
        check_pass_through("readback distinct lanes, cs=1");

        // ============================================================
        // 4. repeat stimulus under cs = 0 (forwarding is combinational,
        //    so the pipeline must keep mirroring regardless of cs)
        // ============================================================
        tb_cs = 1'b0;
        wait (tb_cs === 1'b0);
        @(posedge tb_pipe1_clk);
        check_pass_through("cs=0, values held");

        for (int r = 0; r < NUM_UNITS; r++) begin
            tb_rst  = r[0];                 // toggle rst under cs=0
            step_addr();
            print_state($sformatf("cs=0 step %0d", r));
            check_pass_through($sformatf("cs=0 step %0d", r));
        end

        // ============================================================
        // 5. end the simulation
        // ============================================================
        if (errors == 0)
            $display("time=%0t, RESULT, ALL CHECKS PASSED", $time);
        else
            $display("time=%0t, RESULT, FAILED with %0d mismatch(es)", $time, errors);

        $finish;
    end


endmodule
