`timescale 1ns / 1ps
/*
    Top Module:  PE
    Data:        DATA_WIDTH is the width of input data -> OUT_WORD_SIZE is the width of output data.
    Format:      OUT_WORD_SIZE = DATA_WIDTH << 1; beacuse multiplication happen inside
    Timing:      Sequential Logic
    Reset:       Synchronized Reset [High negedge rst_n]
    Dummy Data:  {DATA_WIDTH{1'b0}}

    Function:   Output Stationary.
            
                        i_data_top (previous accumulated result)
                                  |
                                  v    
 (weights and input)  i_data -->|¯¯¯|--> o_data_right
                                |___|  
                                  |    
                                  v    
                        o_data_down (after accumulated result)
            
            Every node has an output value;

    Author:      Jianming Tong (jianming.tong@gatech.edu)
*/


module PE #(
    parameter DATA_WIDTH = 8,
    parameter ACCU_DATA_WIDTH = (DATA_WIDTH << 1) // By default the frist level for the input data.
)(
    // timing signals
    clk,
    rst_n,

    // data signals
    i_data_top,
    i_valid_top,
    i_data_left,
    i_valid_left,
    o_data_right,
    o_valid_right,
    o_data_down,
    o_valid_down,

    // command signals
    i_cmd,         // notify the PE to save the i_data_left (which is weights)
    o_cmd
);

    /*
        parameters
    */

    localparam OUT_DATA_WIDTH = ACCU_DATA_WIDTH + 1;
    localparam SIGN_EXTEND_MUL_DATA_WIDTH = (DATA_WIDTH << 1);
    localparam SIGN_EXTEND_ACC_DATA_WIDTH = OUT_DATA_WIDTH;

    /*
        ports
    */

    input                                           clk;
    input                                           rst_n;

    input    [ACCU_DATA_WIDTH - 1 : 0]              i_data_top;
    input                                           i_valid_top;
    input    [DATA_WIDTH - 1 : 0]                   i_data_left;
    input                                           i_valid_left;
    output   [DATA_WIDTH - 1 : 0]                   o_data_right;
    output                                          o_valid_right;
    output   [OUT_DATA_WIDTH - 1 : 0]               o_data_down;
    output                                          o_valid_down;

    input                                           i_cmd;         // 1'b1 means store the external weights inside.
    output                                          o_cmd;

    /*
        inner logics
    */

    reg      [SIGN_EXTEND_MUL_DATA_WIDTH - 1 : 0]   stationary_data_inner;
    reg                                             stationary_valid_inner;
    reg      [DATA_WIDTH - 1 : 0]                   o_data_right_inner;
    reg                                             o_valid_right_inner;
    reg      [OUT_DATA_WIDTH - 1 : 0]               o_data_down_inner;
    reg                                             o_valid_down_inner;
    reg      [SIGN_EXTEND_MUL_DATA_WIDTH - 1 : 0]   res_mul;
    reg                                             res_mul_valid_inner;
    reg                                             o_cmd_inner;
    
    /*
        inner control combinational logics
    */

    wire                                            ctrl_valid_weight_left_in;       
    wire                                            ctrl_evict_inner_right;       
    wire                                            ctrl_multiplication;       
    wire                                            ctrl_accumulate_down;       

    /*
        sign extended wire signals
    */

    wire     [SIGN_EXTEND_MUL_DATA_WIDTH - 1 : 0]   i_data_left_sign_extend;
    wire     [OUT_DATA_WIDTH - 1 : 0]               i_data_top_sign_extend;
    wire     [OUT_DATA_WIDTH - 1 : 0]               res_mul_sign_extend;

    assign   i_data_left_sign_extend = {{(SIGN_EXTEND_MUL_DATA_WIDTH - DATA_WIDTH){i_data_left[DATA_WIDTH - 1]}}, i_data_left};
    assign   i_data_top_sign_extend = {{(OUT_DATA_WIDTH - ACCU_DATA_WIDTH){i_data_top[ACCU_DATA_WIDTH - 1]}}, i_data_top};
    assign   res_mul_sign_extend = (OUT_DATA_WIDTH==SIGN_EXTEND_MUL_DATA_WIDTH)? res_mul : {{(OUT_DATA_WIDTH - SIGN_EXTEND_MUL_DATA_WIDTH){res_mul[SIGN_EXTEND_MUL_DATA_WIDTH - 1]}}, res_mul};

    /*
        weight stationary inside
    */

    assign   ctrl_valid_weight_left_in = i_cmd & i_valid_left;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            stationary_data_inner <= {SIGN_EXTEND_MUL_DATA_WIDTH{1'b0}};
        end
        else
        begin
            stationary_data_inner <= (ctrl_valid_weight_left_in)?i_data_left_sign_extend:stationary_data_inner;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            stationary_valid_inner <= 1'b0;
        end
        else
        begin
            stationary_valid_inner <= (ctrl_valid_weight_left_in)?1'b1:stationary_valid_inner;
        end
    end

    /*
        inner data shift right
    */

    assign   ctrl_evict_inner_right = i_valid_left & stationary_valid_inner;

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            o_data_right_inner <= {DATA_WIDTH{1'b0}};
        end
        else
        begin
            o_data_right_inner <= (ctrl_valid_weight_left_in)? ((stationary_valid_inner)?stationary_data_inner:{DATA_WIDTH{1'b0}}) : ((i_valid_left)?i_data_left:{DATA_WIDTH{1'b0}});
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            o_valid_right_inner <= {1'b0};
        end
        else
        begin
            o_valid_right_inner <= (ctrl_valid_weight_left_in)?stationary_valid_inner:i_valid_left;
        end
    end

    /*
        inner multiplication results 
    */

    assign ctrl_multiplication = i_valid_left & stationary_valid_inner;

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            res_mul <= {SIGN_EXTEND_MUL_DATA_WIDTH{1'b0}};
        end
        else if(~ctrl_valid_weight_left_in)
        begin
            res_mul <= (ctrl_multiplication)?(stationary_data_inner * i_data_left_sign_extend):{SIGN_EXTEND_MUL_DATA_WIDTH{1'b0}};
        end
        else
        begin
            res_mul <= {SIGN_EXTEND_MUL_DATA_WIDTH{1'b0}};
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            res_mul_valid_inner <= {1'b0};
        end
        else if(~ctrl_valid_weight_left_in)
        begin
            res_mul_valid_inner <= ctrl_multiplication;
        end
        else
        begin
            res_mul_valid_inner <= {1'b0};
        end
    end

    /*
        Output data down
    */

    assign  ctrl_accumulate_down = res_mul_valid_inner & i_valid_top;
    
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            o_data_down_inner <= {OUT_DATA_WIDTH{1'b0}};
        end
        else if(~ctrl_valid_weight_left_in)
        begin
            o_data_down_inner <= (ctrl_accumulate_down)?(res_mul_sign_extend + i_data_top_sign_extend):{OUT_DATA_WIDTH{1'b0}};
        end
        else
        begin
            o_data_down_inner <= {OUT_DATA_WIDTH{1'b0}};
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            o_valid_down_inner <= {1'b0};
        end
        else
        begin
            o_valid_down_inner <= ctrl_accumulate_down;
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            o_cmd_inner <= 1'b0;
        end
        else
        begin
            o_cmd_inner <= i_cmd;
        end
    end

    assign o_data_right = o_data_right_inner;
    assign o_data_down = o_data_down_inner;
    assign o_valid_right = o_valid_right_inner;
    assign o_valid_down = o_valid_down_inner;
    assign o_cmd = o_cmd_inner;

endmodule
