/*
    Top Module:  systolic_array_top_ws_seq
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

module systolic_array_top_ws_seq#(
   parameter NUM_ROW = 8,
   parameter NUM_COL = 8 ,
   parameter DATA_WIDTH = 8
)(
    clk,
    rst_n,

    i_data,          // top input ports
    i_valid,         // input valid
    i_last,          // command to tell the last input signals

    o_data,          // change i_data to weights
    o_valid          // output valid
);

    /*
        localparam
    */  
    localparam WEIGHTS_CYCLE = NUM_ROW;
    localparam OUT_DATA_WIDTH = (DATA_WIDTH << 1) + NUM_ROW - 1;

    /*
        ports
    */
    input                                                       clk;
    input                                                       rst_n;

    input  [NUM_ROW * DATA_WIDTH - 1 : 0]                       i_data;
    input  [NUM_ROW - 1 : 0]                                    i_valid;
    input                                                       i_last;

    output [NUM_COL * OUT_DATA_WIDTH - 1 : 0]                   o_data;
    output [NUM_COL - 1 : 0]                                    o_valid;
 
    /*
        inner logics
    */
    wire   [NUM_ROW * DATA_WIDTH - 1 : 0]                       in_data_inner;
    wire   [NUM_ROW - 1 : 0]                                    in_valid_inner;

    wire   [NUM_COL * DATA_WIDTH - 1 : 0]                       out_data_inner;
    wire   [NUM_COL - 1 : 0]                                    out_valid_inner;

    wire   [NUM_ROW - 1 : 0]                                    in_cmd_inner;
    wire   [NUM_ROW - 1 : 0]                                    out_cmd_inner;

    wire   [NUM_COL * OUT_DATA_WIDTH - 1 : 0]                   res_data_inner;
    wire   [NUM_COL - 1 : 0]                                    res_valid_inner;

    wire                                                        i_cmd;

    systolic_array_control_ws_seq #(
        .WEIGHTS_CYCLE(WEIGHTS_CYCLE),
        .NUM_COL(NUM_COL)
    )controller(
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(i_valid[0]),
        .i_last(i_last),
        .o_cmd(i_cmd)
    );

    assign in_cmd_inner = {NUM_COL{i_cmd}};

    systolic_movement_input#(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL),
        .DATA_WIDTH(1)
    )cmd_pipe(
        .clk(clk),
        .rst_n(rst_n),
        
        .i_data(in_cmd_inner),     // top input ports
        .i_valid({NUM_ROW{1'b1}}), // input valid

        .o_data(out_cmd_inner),    // change i_data to weights
        .o_valid()                 // output valid
    );

    systolic_movement_input#(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL),
        .DATA_WIDTH(DATA_WIDTH)
    )data_pipe(
        .clk(clk),
        .rst_n(rst_n),
        
        .i_data(i_data),            // top input ports
        .i_valid(i_valid),          // input valid

        .o_data(in_data_inner),     // change i_data to weights
        .o_valid(in_valid_inner)    // output valid
    );

    systolic_array_datapath_ws_seq#(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL),
        .DATA_WIDTH(DATA_WIDTH)
    )datapath(
        .clk(clk),
        .rst_n(rst_n),
        
        .i_data(in_data_inner),     // top input ports
        .i_valid(in_valid_inner),   // input valid
        
        // .i_data(i_data),     // top input ports
        // .i_valid(i_valid),   // input valid
        .o_data(res_data_inner),    // change i_data to weights
        .o_valid(res_valid_inner),  // output valid

        // .i_cmd(in_cmd_inner)       // change i_data to weights
        .i_cmd(out_cmd_inner)       // change i_data to weights
    );

    systolic_movement#(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL),
        .DATA_WIDTH(OUT_DATA_WIDTH)
    )output_pipe(
        .clk(clk),
        .rst_n(rst_n),
        
        .i_data(res_data_inner),    // top input ports
        .i_valid(res_valid_inner),  // input valid

        .o_data(o_data),            // change i_data to weights
        .o_valid(o_valid)           // output valid
    );

endmodule
