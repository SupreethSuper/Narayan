`timescale 1ns/1ps

// ============================================================
// Testbench: tb_narayan_bdf  —  Final Integration Test
// DUT: narayan_bdf (scheduler + 4× scratchpad_memory)
//
// Structure
//   Phase 1 – Burst write: 90 values, one per clock cycle.
//             beat_cnt: 0 → 90 after this phase.
//   Wrap    – 10 dummy write cycles to roll beat_cnt 90 → 0.
//   Phase 2 – Read scan: 89 steps, each stepping beat_cnt
//             by 1 (write pulse) then reading the new address.
//             Shows the 89 values committed in phase 1 in order.
//
// Why 89 not 90?
//   Cycle 1 of the burst is the RESET→WRITE FSM transition;
//   the scratchpad doesn't commit a write that cycle, so
//   val[0] (32'd7) is lost. Values val[1]–val[89] are stored.
// ============================================================

module tb_narayan_bdf;

    localparam CLK_PERIOD = 10;

    logic        clk;
    logic        rw_;
    logic        rst;
    logic        cs;
    logic [31:0] data_in;

    wire  [31:0] mem1_out;
    wire  [31:0] mem2_out;
    wire  [31:0] mem3_out;
    wire  [31:0] mem4_out;

    narayan_bdf dut (
        .clk     (clk),
        .rw_     (rw_),
        .rst     (rst),
        .cs      (cs),
        .data_in (data_in),
        .mem1_out(mem1_out),
        .mem2_out(mem2_out),
        .mem3_out(mem3_out),
        .mem4_out(mem4_out)
    );

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        rst     = 1'b0;
        cs      = 1'b0;
        rw_     = 1'b1;
        data_in = 32'd0;
    end

    // ----------------------------------------------------------------
    // Main sequence
    // ----------------------------------------------------------------
    always @(posedge clk) begin

        rst = 1'b1;   // deassert reset
        #10;

        // ============================================================
        // Phase 1: Burst write — 90 values
        // ============================================================
        cs  = 1'b1;
        rw_ = 1'b0;

        #20;

        data_in = 32'd7;       #10;
        $display("time = %t", $time);
        data_in = 32'd13;      #10;
        data_in = 32'd42;      #10;
        data_in = 32'd99;      #10;
        data_in = 32'd128;     #10;
        data_in = 32'd200;     #10;
        data_in = 32'd255;     #10;
        data_in = 32'd512;     #10;
        data_in = 32'd777;     #10;
        data_in = 32'd1000;    #10;
        data_in = 32'd1234;    #10;
        data_in = 32'd1500;    #10;
        data_in = 32'd2048;    #10;
        data_in = 32'd2500;    #10;
        data_in = 32'd3141;    #10;
        data_in = 32'd3500;    #10;
        data_in = 32'd4096;    #10;
        data_in = 32'd4500;    #10;
        data_in = 32'd5000;    #10;
        data_in = 32'd5678;    #10;
        data_in = 32'd6000;    #10;
        data_in = 32'd6789;    #10;
        data_in = 32'd7500;    #10;
        data_in = 32'd8192;    #10;
        data_in = 32'd8500;    #10;
        data_in = 32'd9000;    #10;
        data_in = 32'd9876;    #10;
        data_in = 32'd10000;   #10;
        data_in = 32'd11111;   #10;
        data_in = 32'd12345;   #10;
        data_in = 32'd13000;   #10;
        data_in = 32'd14000;   #10;
        data_in = 32'd15000;   #10;
        data_in = 32'd15625;   #10;
        data_in = 32'd16384;   #10;
        data_in = 32'd17000;   #10;
        data_in = 32'd18000;   #10;
        data_in = 32'd19000;   #10;
        data_in = 32'd19683;   #10;
        data_in = 32'd20000;   #10;
        data_in = 32'd21000;   #10;
        data_in = 32'd22000;   #10;
        data_in = 32'd23000;   #10;
        data_in = 32'd24000;   #10;
        data_in = 32'd25000;   #10;
        data_in = 32'd25600;   #10;
        data_in = 32'd26000;   #10;
        data_in = 32'd27000;   #10;
        data_in = 32'd28000;   #10;
        data_in = 32'd29000;   #10;
        data_in = 32'd30000;   #10;
        data_in = 32'd31000;   #10;
        data_in = 32'd32000;   #10;
        data_in = 32'd32768;   #10;
        data_in = 32'd33333;   #10;
        data_in = 32'd34000;   #10;
        data_in = 32'd35000;   #10;
        data_in = 32'd36000;   #10;
        data_in = 32'd37000;   #10;
        data_in = 32'd38000;   #10;
        data_in = 32'd39000;   #10;
        data_in = 32'd40000;   #10;
        data_in = 32'd41000;   #10;
        data_in = 32'd42000;   #10;
        data_in = 32'd43000;   #10;
        data_in = 32'd44000;   #10;
        data_in = 32'd45000;   #10;
        data_in = 32'd46000;   #10;
        data_in = 32'd47000;   #10;
        data_in = 32'd48000;   #10;
        data_in = 32'd49000;   #10;
        data_in = 32'd50000;   #10;
        data_in = 32'd55000;   #10;
        data_in = 32'd60000;   #10;
        data_in = 32'd65535;   #10;
        data_in = 32'd70000;   #10;
        data_in = 32'd80000;   #10;
        data_in = 32'd90000;   #10;
        data_in = 32'd100000;  #10;
        data_in = 32'd131072;  #10;
        data_in = 32'd200000;  #10;
        data_in = 32'd262144;  #10;
        data_in = 32'd300000;  #10;
        data_in = 32'd400000;  #10;
        data_in = 32'd500000;  #10;
        data_in = 32'd524288;  #10;
        data_in = 32'd1000000; #10;
        data_in = 32'd1048576; #10;
        data_in = 32'd2000000; #10;
        data_in = 32'd4294967; #10;

        $display("[%0t ns] Phase 1 done — 90 values written. beat_cnt = 90.", $time);

        // ============================================================
        // Wrap: 10 dummy write cycles to roll beat_cnt 90 → 0
        // ============================================================
        data_in = 32'd0;
        repeat(10) #10;

        $display("[%0t ns] beat_cnt wrapped to 0. Starting read scan.", $time);

        // ============================================================
        // Phase 2: Read scan — 89 steps
        //
        // Each step:
        //   rw_=0  #10   – 1 write cycle: advances beat_cnt by 1.
        //                  (Odd steps commit a dummy write; even steps
        //                   are READ→WRITE transitions with no commit.)
        //   rw_=1  #10   – FSM WRITE→READ transition
        //          #10   – output registers settle
        //   $display     – capture result
        //
        // beat_cnt 1 → value 32'd13  (mem1_out)
        // beat_cnt 5 → value 32'd200 (mem2_out)
        // beat_cnt 10 → value 32'd1234 (mem3_out)  etc.
        // ============================================================
        $display("starting read now. Time  =  %t", $time);
        for (int s = 1; s <= 89; s++) begin
            // The advance pulse below forces cs=1,rw_=0 for one cycle, which
            // unavoidably re-enters WRITE_STATE and commits data_in into the
            // cell beat_cnt is about to leave. Feed back the value already
            // sitting there so the forced write is a same-value no-op
            // instead of clobbering it with the stale data_in=0.
            case (dut.b2v_inst4.mem_idx)
                0: data_in = mem1_out;
                1: data_in = mem2_out;
                2: data_in = mem3_out;
                3: data_in = mem4_out;
            endcase
            rw_ = 1'b0; #10;       // advance beat_cnt to s
            rw_ = 1'b1; #10; #10;  // read at beat_cnt = s
            $display("[%0t ns] scan %2d :  mem1=%-10d  mem2=%-10d  mem3=%-10d  mem4=%-10d",
                      $time, s, mem1_out, mem2_out, mem3_out, mem4_out);
        end
        $display("read done. Time = %t", $time);

        $display("[%0t ns] Done.", $time);
        $finish;
    end

    initial begin
        $dumpfile("narayan_bdf.vcd");
        $dumpvars(0, tb_narayan_bdf);
    end

endmodule
