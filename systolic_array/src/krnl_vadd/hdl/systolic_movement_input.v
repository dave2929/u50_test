`timescale 1ns / 1ps

/*
    Top Module:  systolic_movement_input
    Data:        DATA_WIDTH is the width of input data
    Timing:      Sequential Logic
    Reset:       Synchronized Reset [negedge rst_n]
    Dummy Data:  {DATA_WIDTH{1'b0}}

    Function:   


    row 0    [0*DW+:DW] i_data                       -->|¯¯¯|-->  o_data [0*DW+:DW]
                                                        |___|            
                                                       
    row 1    [1*DW+:DW] i_data                -->|¯¯¯|--|¯¯¯|-->  o_data [1*DW+:DW]
                                                 |___|  |___|                
                                                                  
    row 2    [2*DW+:DW] i_data         -->|¯¯¯|--|¯¯¯|--|¯¯¯|-->  o_data [2*DW+:DW]
                                          |___|  |___|  |___|          
                                                                       
    row 3    [3*DW+:DW] i_data  -->|¯¯¯|--|¯¯¯|--|¯¯¯|--|¯¯¯|-->  o_data [3*DW+:DW]
                                   |___|  |___|  |___|  |___|          
                                                                        
    Author:      Jianming Tong (jianming.tong@gatech.edu)
*/


module systolic_movement_input#(
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

    input  [NUM_ROW * DATA_WIDTH - 1 : 0]                        i_data;
    input  [NUM_ROW - 1 : 0]                                     i_valid;

    output [NUM_ROW * DATA_WIDTH - 1 : 0]                        o_data;
    output [NUM_ROW - 1 : 0]                                     o_valid;
    
    /*
        Data - Row Movement
    */
    genvar gi;
    genvar i;

    generate
        for(gi=0;gi<NUM_ROW;gi=gi+1)
        begin: row
            reg [DATA_WIDTH - 1:0] r [0:gi];
        end

        for(gi=0;gi<NUM_ROW;gi=gi+1)
        begin: row_valid
            reg                    r [0:gi];
        end
    endgenerate

    /*
        Output Data Movement
    */
    generate
        for(gi=0;gi<NUM_ROW;gi=gi+1)
        begin: row_sa_rst_n
            for(i=0;i<gi;i=i+1)
            begin:loop_row
                always@(posedge clk or negedge rst_n)
                begin
                    if(!rst_n)
                    begin
                        row[gi].r[i+1] <= 0;
                    end
                    else
                    begin
                        row[gi].r[i+1] <= row[gi].r[i];
                    end
                end
            end
        end
        
        for(gi=0;gi<NUM_ROW;gi=gi+1)
        begin:row_external_in
            always@(posedge clk or negedge rst_n)
            begin
                if(!rst_n)
                begin
                    row[gi].r[0] <= 0;
                end
                else
                begin
                    row[gi].r[0] <= i_data[gi*DATA_WIDTH+:DATA_WIDTH];
                end
            end
        end
    endgenerate

    /*
        Output Valid Movement
    */
    generate
        for(gi=0;gi<NUM_ROW;gi=gi+1)
        begin: row_valid_sa_rst_n
            for(i=0;i<gi;i=i+1)
            begin:loop_row
                always@(posedge clk or negedge rst_n)
                begin
                    if(!rst_n)
                    begin
                        row_valid[gi].r[i+1] <= 0;
                    end
                    else
                    begin
                        row_valid[gi].r[i+1] <= row_valid[gi].r[i];
                    end
                end
            end
        end
        
        for(gi=0;gi<NUM_ROW;gi=gi+1)
        begin:row_valid_external_in
            always@(posedge clk or negedge rst_n)
            begin
                if(!rst_n)
                begin
                    row_valid[gi].r[0] <= 0;
                end
                else
                begin
                    row_valid[gi].r[0] <= i_valid[gi];
                end
            end
        end
    endgenerate

    generate
        for(gi=0;gi<NUM_ROW;gi=gi+1)
        begin
            assign o_data[gi*DATA_WIDTH+:DATA_WIDTH] = row[gi].r[gi];
            assign o_valid[gi] = row_valid[gi].r[gi];
        end
    endgenerate

endmodule
