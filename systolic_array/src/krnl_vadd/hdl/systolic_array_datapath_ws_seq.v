`timescale 1ns / 1ps
/*
    Top Module:  systolic_array_datapath_ws_seq
    Data:        DATA_WIDTH is the width of input data -> OUT_WORD_SIZE is the width of output data.
    Format:      OUT_WORD_SIZE = DATA_WIDTH << 1; beacuse multiplication happen inside
    Timing:      Sequential Logic
    Reset:       Synchronized Reset [High negedge rst_n]
    Dummy Data:  {DATA_WIDTH{1'b0}}

    Function:   Output Stationary.


         i_data[0*IWS+:IWS]   -->|¯¯¯|--|¯¯¯|--|¯¯¯|--|¯¯¯|
                                 |___|  |___|  |___|  |___|
                                   |      |      |      |
         i_data[1*IWS+:IWS]   -->|¯¯¯|--|¯¯¯|--|¯¯¯|--|¯¯¯|
                                 |___|  |___|  |___|  |___|
                                   |      |      |      |
             ...              -->|¯¯¯|--|¯¯¯|--|¯¯¯|--|¯¯¯|
                                 |___|  |___|  |___|  |___|
                                   |      |      |      |
     i_data[NUM_ROWS*IWS+:IWS]-->|¯¯¯|--|¯¯¯|--|¯¯¯|--|¯¯¯|
                                 |___|  |___|  |___|  |___|
                                   |      |      |      |
                                   v      v      v      v
                                o_data o_data o_data o_data
                          [0*IWS+:IWS]               [NUM_ROWS*IWS+:IWS]

            Every node has an output value;

    Author:      Jianming Tong (jianming.tong@gatech.edu)
*/

module systolic_array_datapath_ws_seq#(
   parameter NUM_ROW = 8,
   parameter NUM_COL = 8 ,
   parameter DATA_WIDTH = 8
)(
    clk,
    rst_n,

    i_data,          // top input ports
    i_valid,         // input valid
    o_data,          // change i_data to weights
    o_valid,         // output valid

    i_cmd            // change i_data to weights
);

    /*
        localparam
    */
    localparam  OUT_DATA_WIDTH = (DATA_WIDTH << 1) + NUM_ROW - 1;
    localparam  ACCU_DATA_WIDTH = DATA_WIDTH << 1;

    /*
        ports
    */
    input                                                        clk;
    input                                                        rst_n;

    input  [NUM_ROW * DATA_WIDTH - 1 : 0]                        i_data;
    input  [NUM_ROW - 1 : 0]                                     i_valid;

    output [NUM_COL * OUT_DATA_WIDTH - 1 : 0]                    o_data;
    output [NUM_COL - 1 : 0]                                     o_valid;

    input  [NUM_COL - 1 : 0]                                     i_cmd;

    /*
        inner logics
    */
    wire                                                         o_valid_down[0:NUM_ROW * NUM_COL - 1];

    wire   [DATA_WIDTH - 1 : 0]                                  o_PE_right[0:NUM_ROW * NUM_COL- - 1];
    wire                                                         o_valid_right[0:NUM_ROW * NUM_COL- 1];

    reg    [DATA_WIDTH - 1 : 0]                                  i_PE_left[0:NUM_ROW - 1];
    reg                                                          i_PE_valid_left[0:NUM_ROW - 1];

    wire                                                         o_cmd_inner[0:NUM_ROW * NUM_COL- 1];

    genvar gi,gj;
    genvar i,j;

    generate
        for (gi=0;gi<NUM_ROW;gi=gi+1)
        begin: top_down_conn
            wire [ACCU_DATA_WIDTH + gi - 1:0]  o_PE_down[0: NUM_COL - 1];
        end
    endgenerate

    /*
        instaniate 2D PE array
    */
    generate
        for(gi=0;gi<NUM_ROW;gi=gi+1) begin: pe_row
            for(gj=0;gj<NUM_COL;gj=gj+1) begin: pe_col
                if (gi==0 && gj==0) begin: top_left
                    PE #(DATA_WIDTH, ((DATA_WIDTH<<1)+gi-1)) pe_inst(.clk(clk), .rst_n(rst_n), .i_data_top({(ACCU_DATA_WIDTH-1){1'b0}}), .i_valid_top((~i_cmd[gi])), .i_data_left(i_data[gi * DATA_WIDTH+:DATA_WIDTH]), .i_valid_left(i_valid[gi]),
                    .o_data_right(o_PE_right[gi*NUM_COL + gj]), .o_valid_right(o_valid_right[gi*NUM_COL + gj]), .o_data_down(top_down_conn[gi].o_PE_down[gj]), .o_valid_down(o_valid_down[gi*NUM_COL + gj]), .i_cmd(i_cmd[gi]), .o_cmd(o_cmd_inner[gi*NUM_COL + gj]));
                end
                else if (gi==0) begin: top
                    PE #(DATA_WIDTH, ((DATA_WIDTH<<1)+gi-1)) pe_inst(.clk(clk), .rst_n(rst_n), .i_data_top({(ACCU_DATA_WIDTH-1){1'b0}}), .i_valid_top((~i_cmd[gi])), .i_data_left(o_PE_right[gi*NUM_COL + (gj-1)]), .i_valid_left(o_valid_right[gi*NUM_COL + (gj-1)]),
                    .o_data_right(o_PE_right[gi*NUM_COL + gj]), .o_valid_right(o_valid_right[gi*NUM_COL + gj]), .o_data_down(top_down_conn[gi].o_PE_down[gj]), .o_valid_down(o_valid_down[gi*NUM_COL + gj]), .i_cmd(o_cmd_inner[gi*NUM_COL + (gj-1)]), .o_cmd(o_cmd_inner[gi*NUM_COL + gj]));
                end
                else if (gj==0) begin: left
                    PE #(DATA_WIDTH, ((DATA_WIDTH<<1)+gi-1)) pe_inst(.clk(clk), .rst_n(rst_n), .i_data_top(top_down_conn[gi-1].o_PE_down[gj]), .i_valid_top(o_valid_down[(gi-1)*NUM_COL + gj]), .i_data_left(i_data[gi * DATA_WIDTH+:DATA_WIDTH]), .i_valid_left(i_valid[gi]),
                    .o_data_right(o_PE_right[gi*NUM_COL + gj]), .o_valid_right(o_valid_right[gi*NUM_COL + gj]), .o_data_down(top_down_conn[gi].o_PE_down[gj]), .o_valid_down(o_valid_down[gi*NUM_COL + gj]), .i_cmd(i_cmd[gi]), .o_cmd(o_cmd_inner[gi*NUM_COL + gj]));
                end
                else if( gj==(NUM_COL-1) )
                begin: right
                    PE #(DATA_WIDTH, ((DATA_WIDTH<<1)+gi-1)) pe_inst(.clk(clk), .rst_n(rst_n), .i_data_top(top_down_conn[gi-1].o_PE_down[gj]), .i_valid_top(o_valid_down[(gi-1)*NUM_COL + gj]), .i_data_left(o_PE_right[gi*NUM_COL + (gj-1)]), .i_valid_left(o_valid_right[gi*NUM_COL + (gj-1)]),
                    .o_data_right(o_PE_right[gi*NUM_COL + gj]), .o_valid_right(o_valid_right[gi*NUM_COL + gj]), .o_data_down(top_down_conn[gi].o_PE_down[gj]), .o_valid_down(o_valid_down[gi*NUM_COL + gj]), .i_cmd(o_cmd_inner[gi*NUM_COL + (gj-1)]), .o_cmd(o_cmd_inner[gi*NUM_COL + gj]));
                end
                else begin: other
                    PE #(DATA_WIDTH, ((DATA_WIDTH<<1)+gi-1)) pe_inst(.clk(clk), .rst_n(rst_n), .i_data_top(top_down_conn[gi-1].o_PE_down[gj]), .i_valid_top(o_valid_down[(gi-1)*NUM_COL + gj]), .i_data_left(o_PE_right[gi*NUM_COL + (gj-1)]), .i_valid_left(o_valid_right[gi*NUM_COL + (gj-1)]),
                    .o_data_right(o_PE_right[gi*NUM_COL + gj]), .o_valid_right(o_valid_right[gi*NUM_COL + gj]), .o_data_down(top_down_conn[gi].o_PE_down[gj]), .o_valid_down(o_valid_down[gi*NUM_COL + gj]), .i_cmd(o_cmd_inner[gi*NUM_COL + (gj-1)]), .o_cmd(o_cmd_inner[gi*NUM_COL + gj]));
                end
            end
        end
    endgenerate

    /*
        Output Signals
    */
    generate
        for(gj=0; gj<NUM_COL; gj=gj+1)
        begin
            assign o_data[gj*OUT_DATA_WIDTH+:OUT_DATA_WIDTH] = top_down_conn[NUM_ROW-1].o_PE_down[gj]; // col_out[gj].c[0];
            assign o_valid[gj] = o_valid_down[(NUM_ROW-1)*NUM_COL + gj]; // col_valid_out[gj].c[0];
        end
    endgenerate

endmodule
