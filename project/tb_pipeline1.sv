`include "nar_params.vh"
`include "scheduler_params.vh"
`timescale 1ns/1ps

module tb_pipeline1();
    
    localparam DATA_WIDTH = NAR_NUM_BITS;
    localparam NUM_UNITS = SCHED_MEM_UNITS;

    logic tb_clk;
    logic tb_rst;
    logic tb_cs;
    logic [DATA_WIDTH-1:0] tb_mem1_out;
    logic [DATA_WIDTH-1:0] tb_mem2_out;
    logic [DATA_WIDTH-1:0] tb_mem3_out;
    logic [DATA_WIDTH-1:0] tb_mem4_out;
    logic tb_pipe1_clk;
    logic tb_pipe1_rst;
    logic tb_pipe1_cs;
    logic [DATA_WIDTH-1:0] tb_pipe1_mem1_out;
    logic [DATA_WIDTH-1:0] tb_pipe1_mem2_out;
    logic [DATA_WIDTH-1:0] tb_pipe1_mem3_out;
    logic [DATA_WIDTH-1:0] tb_pipe1_mem4_out;

    pipeline1 #( 
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_UNITS(NUM_UNITS)
    ) uut(
        .clk(tb_clk),
        .rst(tb_rst),
        .cs(tb_cs),
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

    // rotation set used in the "ideal operation" phase
    logic [DATA_WIDTH-1:0] vals [0:NUM_UNITS-1];
    logic [DATA_WIDTH-1:0] tmp;


    always begin : clk_gen
        #1 tb_clk = ~tb_clk;
    end


    initial begin : wave_gen
        $dumpfile("pipeline1_waves.vcd");
        $dumpvars(0,tb_pipeline1);
    end


    //testplan 
    //1. reset the pulse, once with the cs = 1, and once with cs =0
    //2. put the reset high for cs = 1 for 2 clock high, and bring it back to low
    //3. bring back to ideal opereating limits. Zero out, all the mems, and rotate the values through mem1_out, and so on
    //4. test all the stimul under cs = 0 
    //5. end the simulation with $finish

    //---------------display style--------------------
    //1. use $display to display the values of the signals
    //3. use $strobe to display the values of the signals
    //4. use $finish to end the simulation
    //5. Use the format "time, signal name, value of the signal"

    //-------------delay----------------------
    //1. do not use "#" delay
    //2. use "@ posedge" and "@ negedge" clock for the delay
    //3. After the signal is set, use wait command, so as to set the signal, and then use @ to settle the signal


    //--------------checks------------------
    //1. use tasks to check the outputs of the dut with the expected values


    // ----------------------------------------------------------------
    // check_pass_through
    // pipeline1 is a purely combinational pass-through, so every
    // pipe1_* output must equal the corresponding driven input at the
    // moment of the check. Any mismatch is counted in `errors`.
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
    // Dumps the settled input/output snapshot with $strobe (end of the
    // current timestep) in "time, signal name, value" style.
    // ----------------------------------------------------------------
    task automatic print_state(input string tag);
        $strobe("time=%0t, state[%s], rst=%b cs=%b | in  mem1=%h mem2=%h mem3=%h mem4=%h",
                 $time, tag, tb_rst, tb_cs, tb_mem1_out, tb_mem2_out, tb_mem3_out, tb_mem4_out);
        $strobe("time=%0t, state[%s], pipe1_rst=%b pipe1_cs=%b | out mem1=%h mem2=%h mem3=%h mem4=%h",
                 $time, tag, tb_pipe1_rst, tb_pipe1_cs,
                 tb_pipe1_mem1_out, tb_pipe1_mem2_out, tb_pipe1_mem3_out, tb_pipe1_mem4_out);
    endtask


    initial begin : test_stimulus

        // clk_gen delays #1 before its first toggle, so initializing
        // here at time 0 wins the race and gives a clean clock.
        tb_clk = 1'b0;

        // ideal quiescent inputs
        tb_rst      = 1'b0;
        tb_cs       = 1'b0;
        tb_mem1_out = '0;
        tb_mem2_out = '0;
        tb_mem3_out = '0;
        tb_mem4_out = '0;
        $display("time=%0t, INFO, tb_pipeline1 start", $time);

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
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        check_pass_through("rst deassert, cs=1");

        tb_cs  = 1'b0;
        tb_rst = 1'b1;
        wait (tb_cs === 1'b0 && tb_rst === 1'b1);
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        print_state("rst pulse, cs=0");
        check_pass_through("rst pulse, cs=0");

        tb_rst = 1'b0;
        wait (tb_rst === 1'b0);
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        check_pass_through("rst deassert, cs=0");

        // ============================================================
        // 2. reset high for cs = 1 for 2 clock highs, then bring low
        // ============================================================
        tb_cs  = 1'b1;
        tb_rst = 1'b1;
        wait (tb_cs === 1'b1 && tb_rst === 1'b1);
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        check_pass_through("rst hold, clk high 1");
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        check_pass_through("rst hold, clk high 2");

        tb_rst = 1'b0;
        wait (tb_rst === 1'b0);
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        check_pass_through("rst released after 2 highs");

        // ============================================================
        // 3. ideal operating limits: zero the mems, then rotate a set
        //    of distinct values through mem1_out, mem2_out, ...
        // ============================================================
        tb_rst      = 1'b0;
        tb_cs       = 1'b1;
        tb_mem1_out = '0;
        tb_mem2_out = '0;
        tb_mem3_out = '0;
        tb_mem4_out = '0;
        wait (tb_cs === 1'b1 && tb_rst === 1'b0);
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        check_pass_through("mems zeroed, cs=1");

        vals[0] = 32'hDEAD_0001;
        vals[1] = 32'hDEAD_0002;
        vals[2] = 32'hDEAD_0003;
        vals[3] = 32'hDEAD_0004;

        for (int r = 0; r < NUM_UNITS; r++) begin
            tb_mem1_out = vals[0];
            tb_mem2_out = vals[1];
            tb_mem3_out = vals[2];
            tb_mem4_out = vals[3];
            wait (tb_mem1_out === vals[0]);
            @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
            print_state($sformatf("rotate step %0d, cs=1", r));
            check_pass_through($sformatf("rotate step %0d, cs=1", r));

            // rotate the set left by one position
            tmp     = vals[0];
            vals[0] = vals[1];
            vals[1] = vals[2];
            vals[2] = vals[3];
            vals[3] = tmp;
        end

        // ============================================================
        // 4. repeat the stimulus under cs = 0 (pass-through is
        //    combinational, so it must hold regardless of cs)
        // ============================================================
        tb_cs = 1'b0;
        wait (tb_cs === 1'b0);
        @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
        check_pass_through("cs=0, values held");

        vals[0] = 32'hBEEF_0001;
        vals[1] = 32'hBEEF_0002;
        vals[2] = 32'hBEEF_0003;
        vals[3] = 32'hBEEF_0004;

        for (int r = 0; r < NUM_UNITS; r++) begin
            tb_mem1_out = vals[0];
            tb_mem2_out = vals[1];
            tb_mem3_out = vals[2];
            tb_mem4_out = vals[3];
            // exercise rst under cs=0 as well
            tb_rst = r[0];
            wait (tb_mem1_out === vals[0]);
            @(posedge tb_pipe1_clk);   // settle on DUT's propagated clock (avoids sampling race on live clk)
            check_pass_through($sformatf("rotate step %0d, cs=0", r));

            tmp     = vals[0];
            vals[0] = vals[1];
            vals[1] = vals[2];
            vals[2] = vals[3];
            vals[3] = tmp;
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