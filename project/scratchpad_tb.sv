`include "nar_params.vh"

module scratchpad_tb;

    localparam DATA_WIDTH = NAR_NUM_BITS;
    localparam CLK_PERIOD = 10;

    logic clk;
    logic rst;
    logic [DATA_WIDTH-1:0] red, green, blue;
    logic [DATA_WIDTH-1:0] red_out, green_out, blue_out;

    // Instantiate DUT
    scratchpad #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(NAR_MAT_ROWS),
        .COLS(NAR_MAT_COLS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .red(red),
        .green(green),
        .blue(blue),
        .red_out(red_out),
        .green_out(green_out),
        .blue_out(blue_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        $display("=== RGB Scratchpad Test ===");
        
        // Initialize
        rst = 0;
        red = 0;
        green = 0;
        blue = 0;
        #10;
        
        // Release reset
        rst = 1;
        #10;
        
        // Test 1: Write data
        $display("Test 1: Input R=0xAA, G=0xBB, B=0xCC");
        red = 32'hAA;
        green = 32'hBB;
        blue = 32'hCC;
        #10;
        $display("Output: R=0x%h, G=0x%h, B=0x%h (delayed by 1 cycle)", red_out, green_out, blue_out);
        
        // Test 2: Check data appears after clock
        #10;
        $display("Test 2: After clock, R=0x%h, G=0x%h, B=0x%h", red_out, green_out, blue_out);
        
        // Test 3: Change inputs
        red = 32'hDD;
        green = 32'hEE;
        blue = 32'hFF;
        #10;
        $display("Test 3: After new input, R=0x%h, G=0x%h, B=0x%h", red_out, green_out, blue_out);
        
        // Test 4: Reset test
        #10;
        rst = 0;
        #10;
        $display("Test 4: After reset, R=0x%h, G=0x%h, B=0x%h (should be 0)", red_out, green_out, blue_out);
        
        $display("=== Test Complete ===");
        $finish;
    end

    // Dump waveforms
    initial begin
        $dumpfile("scratchpad_tb.vcd");
        $dumpvars(0, scratchpad_tb);
    end

endmodule