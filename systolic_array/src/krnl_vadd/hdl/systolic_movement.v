`timescale 1ns / 1ps
/*
    Top Module:  systolic_movement
    Data:        DATA_WIDTH is the width of input data
    Timing:      Sequential Logic
    Reset:       Synchronized Reset [negedge rst_n]
    Dummy Data:  {DATA_WIDTH{1'b0}}

    Function:   

         [0*DW+:DW]            [3*DW+:DW]    
           i_data                i_data  
              |      |      |      |
              v      v      v      v
            |¯¯¯|--|¯¯¯|--|¯¯¯|--|¯¯¯|
            |___|  |___|  |___|  |___|
              |      |      |      |
            |¯¯¯|--|¯¯¯|--|¯¯¯|    v 
            |___|  |___|  |___|  o_data
              |      |      |  [3*DW+:DW]
            |¯¯¯|--|¯¯¯|    v
            |___|  |___|  o_data 
              |      |
            |¯¯¯|    v
            |___|  o_data
              |
              v
           o_data
         [0*DW+:DW]               

        DW = DATA_WIDTH

    Author:      Jianming Tong (jianming.tong@gatech.edu)
*/

module systolic_movement#(
   parameter NUM_ROW = 8,
   parameter NUM_COL = 8 ,
   parameter DATA_WIDTH = 8
)(
    clk,
    rst_n,

    i_data,          // top input ports
    i_valid,         // input valid
    o_data,          // change i_data to weights
    o_valid          // output valid
);

    input                                                        clk;
    input                                                        rst_n;

    input  [NUM_COL * DATA_WIDTH - 1 : 0]                        i_data;
    input  [NUM_COL - 1 : 0]                                     i_valid;

    output [NUM_COL * DATA_WIDTH - 1 : 0]                        o_data;
    output [NUM_COL - 1 : 0]                                     o_valid;
    
    /*
        o_PE_down[0]     o_PE_down[1]     o_PE_down[1]     o_PE_down[2]

                                    |  dataflow direction
                                    v

        col_out[0].c[3]  col_out[1].c[2]  col_out[2].c[1]  col_out[3].c[0]
        col_out[0].c[2]  col_out[1].c[1]  col_out[2].c[0]
        col_out[0].c[1]  col_out[1].c[0]
        col_out[0].c[0]
    */

    genvar gi,gj;
    genvar i,j;

    generate
        for(gj=0; gj<NUM_COL; gj=gj+1)
        begin: col
            reg [DATA_WIDTH - 1:0] c [0:NUM_ROW-1-gj];
        end

        for(gj=0; gj<NUM_COL; gj=gj+1)
        begin: col_valid
            reg                    c [0:NUM_ROW-1-gj];
        end
    endgenerate

    /*
        Output Data Movement
    */
    generate
        for(gj=0; gj<NUM_COL; gj=gj+1)
        begin: col_sa_rst_n
            for(j=0; j<(NUM_COL-1-gj); j=j+1)
            begin:loop_col
                always@(posedge clk or negedge rst_n)
                begin
                    if(!rst_n)
                    begin
                        col[gj].c[j+1] <= 0;
                    end
                    else
                    begin
                        col[gj].c[j+1] <= col[gj].c[j];
                    end
                end
            end
        end
        
        for(gj=0; gj<NUM_COL; gj=gj+1)
        begin:col_external_in
            always@(posedge clk or negedge rst_n)
            begin
                if(!rst_n)
                begin
                    col[gj].c[0] <= 0;
                end
                else
                begin
                    col[gj].c[0] <= i_data[gj*DATA_WIDTH+:DATA_WIDTH];
                end
            end
        end
    endgenerate

    /*
        Output Valid Movement
    */
    generate
        for(gj=0; gj<NUM_COL; gj=gj+1)
        begin: col_valid_sa_rst_n
            for(j=0; j<(NUM_COL-1-gj); j=j+1)
            begin:loop_col
                always@(posedge clk or negedge rst_n)
                begin
                    if(!rst_n)
                    begin
                        col_valid[gj].c[j+1] <= 0;
                    end
                    else
                    begin
                        col_valid[gj].c[j+1] <= col_valid[gj].c[j];
                    end
                end
            end
        end
        
        for(gj=0; gj<NUM_COL; gj=gj+1)
        begin:col_valid_external_in
            always@(posedge clk or negedge rst_n)
            begin
                if(!rst_n)
                begin
                    col_valid[gj].c[0] <= 0;
                end
                else
                begin
                    col_valid[gj].c[0] <= i_valid[gj];
                end
            end
        end
    endgenerate

    generate
        for(gj=0;gj<NUM_COL;gj=gj+1)
        begin
            assign o_data[gj*DATA_WIDTH+:DATA_WIDTH] = col[gj].c[NUM_COL-1-gj];
            assign o_valid[gj] = col_valid[gj].c[NUM_COL-1-gj];
        end
    endgenerate

endmodule
