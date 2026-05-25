`include "nar_params.vh"

module scratchpad #(
    parameter DATA_WIDTH = NAR_NUM_BITS,
    parameter ROWS       = NAR_MAT_ROWS,
    parameter COLS       = NAR_MAT_COLS
)

(
    input logic  clk,
    input logic  rst,
    input logic  [DATA_WIDTH-1:0] red,
    input logic  [DATA_WIDTH-1:0] green,
    input logic  [DATA_WIDTH-1:0] blue,
    output logic [DATA_WIDTH-1:0] red_out   [0:ROWS-1][0:COLS-1],
    output logic [DATA_WIDTH-1:0] green_out [0:ROWS-1][0:COLS-1],
    output logic [DATA_WIDTH-1:0] blue_out  [0:ROWS-1][0:COLS-1]
);
    // int counter_red;
    // int counter_green;
    // int counter_blue;

    logic [DATA_WIDTH-1:0] red_pad   [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] green_pad [0:ROWS-1][0:COLS-1];
    logic [DATA_WIDTH-1:0] blue_pad  [0:ROWS-1][0:COLS-1];

    assign red_out   = red_pad;
    assign green_out = green_pad;
    assign blue_out  = blue_pad;

    initial begin
        for (int i = 0; i < ROWS; i++)
        begin
            for (int j = 0; j < COLS; j++)
            begin
                red_pad[i][j] = 0;
                green_pad[i][j] = 0;
                blue_pad[i][j] = 0;
            end
        end
    end


    always_ff @(posedge clk or negedge rst)
    begin
        if(~rst)
        begin
            for (int i = 0; i < ROWS; i++)
                for (int j = 0; j < COLS; j++)
                begin
                    red_pad[i][j]   <= 0;
                    green_pad[i][j] <= 0;
                    blue_pad[i][j]  <= 0;
                end
        end
        else
        begin


            for (int i = 0; i < ROWS; i++)
            begin
                for (int j = 0; j < COLS; j++)
                begin
                    red_pad[i][j] <= red;
                    // counter_red <= counter_red + 1;

                    green_pad[i][j] <= green;
                    // counter_green <= counter_green + 1;

                    blue_pad[i][j] <= blue;
                    // counter_blue <= counter_blue + 1;
                end
            end



        end
    end

endmodule