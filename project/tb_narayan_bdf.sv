`timescale 1ns/1ps

// ============================================================
// Testbench: tb_narayan_bdf  —  Final Integration Test
// DUT: narayan_bdf (scheduler + 4× scratchpad_memory)
//
// Structure
//   Phase 1 – Write 5 values, pulsing `next` between each one to
//             step the scheduler's beat_cnt to the next address.
//             val[0] (32'd1) lands on beat 0 during the FSM's
//             unavoidable RESET_STATE->WRITE_STATE one-cycle latency,
//             so it's lost; val[1]..val[4] (32'd2..32'd5) commit at
//             beats 1..4 (all mem1, mem_idx=0).
//   Wrap    – 96 silent `next` pulses to wrap beat_cnt 4 -> 0
//             (TOTAL_ADDRS = 100, so (0 - 4 + 100) mod 100 = 96).
//   Phase 2 – Read scan: 4 steps, each pulsing `next` to advance to
//             beat 1..4 and reading the value back. `next` is the
//             sole address-advance signal — rw_ stays 1 throughout,
//             no toggling needed to step the read address.
// ============================================================

module tb_narayan_bdf;

    localparam CLK_PERIOD = 10;

    logic        clk;
    logic        rw_;
    logic        rst;
    logic        cs;
    logic        next;
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
        .next    (next),
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
        next    = 1'b0;
        data_in = 32'd0;
        $display("from testbench file");
    end

    // ----------------------------------------------------------------
    // Pulses `next` high for one cycle then low for one cycle, so the
    // scheduler's edge detector (next && !next_d) sees exactly one
    // rising edge and beat_cnt advances by exactly one beat.
    // ----------------------------------------------------------------
    task automatic step_addr();
        next = 1'b1; #10;
        next = 1'b0; #10;
    endtask

    // ----------------------------------------------------------------
    // Main sequence
    // ----------------------------------------------------------------
    always @(posedge clk) begin

        rst = 1'b1;   // deassert reset
        #10;

        // ============================================================
        // Write 5 values. No dead time between cs/rw_ and the first
        // data_in — beat_cnt=0 is sacrificed to the FSM's unavoidable
        // RESET_STATE->WRITE_STATE one-cycle latency, so 32'd1 is lost
        // and 32'd2..32'd5 land at beat_cnt 1..4 (all mem1, mem_idx=0).
        // Address advance is via step_addr() (next), not rw_.
        // ============================================================
        cs  = 1'b1;
        rw_ = 1'b0;
       wait(cs == 1'b1 && rw_ == 1'b0);

        data_in = 32'd1;    
        #10;
        step_addr();

        data_in = 32'd2;    
        #10;
        step_addr();
        
        data_in = 32'd3;    
        #10;
        step_addr();
        
        data_in = 32'd4;    
        #10;
        step_addr();

        
        data_in = 32'd5;    
        #10;
        

        step_addr();
        data_in = 32'd6;    
        #10;

        step_addr();
        data_in = 32'd7;    
        #10;
        step_addr();
        data_in = 32'd8;    
        #10;

        step_addr();
        data_in = 32'd9;    
        #10;
        
        step_addr();
        data_in = 32'd10;    
        #10;



        // $display("[%0t ns] write phase done.", $time);

        // ============================================================
        // Switch to read mode and wrap beat_cnt 4 -> 0, so the scan
        // below can step forward through beats 1..4 (mem1=2,3,4,5)
        // in the same order they were written.
        // ============================================================
        rw_ = 1'b1;
        wait(rw_);
        
       // repeat (1) @(posedge clk);
        // $display("[%0t ns] seed read : mem1=%0d", $time, mem1_out);
        
        for (int w = 0; w < 10; w++) begin
            step_addr();
        end

        // for (int s = 1; s <= 4; s++) begin
        //     step_addr();           // advance beat_cnt to s
        //     #10;                    // let the registered read settle
        //     $display("[%0t ns] scan %0d : mem1=%0d mem2=%0d mem3=%0d mem4=%0d",
        //                $time, s, mem1_out, mem2_out, mem3_out, mem4_out);
        // end

        $finish;

    end

    initial begin
        $monitor("time = %t data_in=%d, cs = %d, rw_ = %d, next = %d, mem1 = %d, mem2 = %d, mem3 = %d, mem4 = %d", $time,data_in,cs,rw_,next,mem1_out,mem2_out,mem3_out,mem4_out);
    end

    initial begin
        $dumpfile("narayan_bdf.vcd");
        $dumpvars(0, tb_narayan_bdf);
    end

endmodule
