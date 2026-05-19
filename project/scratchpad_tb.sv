`include "nar_params.vh"

module scratchpad_tb;

    // Parameters
    localparam DATA_WIDTH = NAR_NUM_BITS;
    localparam ROWS = NAR_MAT_ROWS;
    localparam COLS = NAR_MAT_COLS;
    
    // Clock period (10ns = 100MHz)
    localparam CLK_PERIOD = 10;

    // Testbench signals
    reg clk;
    reg rst;
    reg [DATA_WIDTH-1:0] data_in;
    wire [DATA_WIDTH-1:0] data_out;

    // Instantiate the DUT (Device Under Test)
    scratchpad #(
        .DATA_WIDTH(DATA_WIDTH),
        .ROWS(ROWS),
        .COLS(COLS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        $display("=== Scratchpad Testbench Started ===");
        $display("DATA_WIDTH = %d", DATA_WIDTH);
        $display("ROWS = %d, COLS = %d", ROWS, COLS);
        
        // Initialize
        rst = 0;
        data_in = 0;
        #10;
        
        // Release reset
        rst = 1;
        #10;
        
        // Test 1: Write and read simple value
        $display("\n--- Test 1: Simple Data Pass ---");
        data_in = 32'hDEADBEEF;
        #10;
        $display("Input: 0x%h, Output: 0x%h", data_in, data_out);
        
        // Test 2: Write another value
        $display("\n--- Test 2: Sequential Data ---");
        data_in = 32'hCAFEBABE;
        #10;
        $display("Input: 0x%h, Output: 0x%h", data_in, data_out);
        
        // Test 3: Write incrementing values
        $display("\n--- Test 3: Incrementing Values ---");
        for(int i = 0; i < 5; i++) begin
            data_in = data_in + 1;
            #10;
            $display("Cycle %d - Input: 0x%h, Output: 0x%h", i, data_in, data_out);
        end
        
        // Test 4: Reset during operation
        $display("\n--- Test 4: Reset Test ---");
        data_in = 32'hFFFFFFFF;
        #10;
        $display("Before Reset - Input: 0x%h, Output: 0x%h", data_in, data_out);
        
        rst = 0;  // Assert reset
        #10;
        $display("After Reset - Output should be 0: 0x%h", data_out);
        
        rst = 1;  // Release reset
        #10;
        
        // Finish simulation
        $display("\n=== Testbench Completed ===");
        $finish;
    end

    // Optional: Waveform dumping for viewing in GTKWave or ModelSim
    initial begin
        $dumpfile("scratchpad_tb.vcd");
        $dumpvars(0, scratchpad_tb);
    end

endmodule