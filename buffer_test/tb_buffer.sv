`timescale 1ns/1ps

module tb_buffer;

    logic in1_test;
    logic out1_test;
    logic clk;

    initial begin
        in1_test = 1'b0;
        clk      = 1'b0;
    end

    always begin
        #5 clk = ~clk;
    end

    buffer UUT (
        .in1  (in1_test),
        .out1 (out1_test)
    );

    initial begin
        #5;
        in1_test = 1'b1;

        #5;
        in1_test = 1'b0;

        #10;
        $finish;
    end

endmodule