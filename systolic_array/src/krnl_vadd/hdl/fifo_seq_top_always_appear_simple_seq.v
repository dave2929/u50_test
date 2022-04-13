`timescale 1ns / 1ps
/*
    Top Module:  fifo_seq_top_always_appear_simple_seq
    Data:        Only data width matters.
    Format:      keeping the input format unchange
    Timing:      Sequential Logic,
    Dummy Data:  {DATA_WIDTH{1'b0}}

    Function:    always write data to the back and read from top 
                 the top value will always appear on the output data bus, and will be threw away every read.
      
                   _______
        i_data --> _|__|__|-> AXI
                          
    Command description:

    Author:      Jianming Tong (jianming.tong@gatech.edu)
*/

module fifo_seq_top_always_appear_simple_seq#(
    parameter DATA_WIDTH = 8,                         // specify the datawidht of input data.
    parameter VALID_WIDTH = 1,                        // specify the datawidht of input data.
    parameter DEPTH = 8                               // specify the depth of fifo_mem.
)(
    // data signals
    clk,
    rst_n,

    i_valid,        // valid input data signal
    i_data,         // input data

    o_valid,        // output valid
    o_data,         // output data

    // control signals
    i_en,           // global enable
    i_wr,           // input write control
    i_rd            // input read control
);

    // data signals
    input                            clk;
    input                            rst_n;

    input  [DATA_WIDTH-1:0]          i_data;
    input  [VALID_WIDTH-1:0]         i_valid;

    output [DATA_WIDTH-1:0]          o_data;
    output [VALID_WIDTH-1:0]         o_valid;

    input                            i_en;
    input                            i_wr;
    input                            i_rd;

    /*
        localparam
    */
    localparam CNT_BIT_WIDTH =  $clog2(DEPTH);

    /*
       first stage var definition
    */
    reg    [DATA_WIDTH-1:0]          fifo_mem[0:DEPTH-1]; 
    reg    [VALID_WIDTH-1:0]         fifo_valid_mem[0:DEPTH-1];
    reg    [DATA_WIDTH-1:0]          o_data_inner;
    reg    [VALID_WIDTH-1:0]         o_valid_inner;

    reg    [CNT_BIT_WIDTH-1:0]       read_cnt; 
    reg    [CNT_BIT_WIDTH-1:0]       write_cnt;  

    /*
        initialize inner register
    */
    integer i,j;

    /*
        write logic        
    */
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            write_cnt <= {CNT_BIT_WIDTH{1'b0}};
        end
        else if(i_en & i_wr)
        begin
            write_cnt <= write_cnt + 1'b1;
        end
        else
        begin
            write_cnt <= write_cnt;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            for(i=0; i< DEPTH; i=i+1)
            begin
                fifo_mem[i] <= {DATA_WIDTH{1'b0}};
                fifo_valid_mem[i] <= {VALID_WIDTH{1'b0}};
            end
        end
        else if(i_en & i_wr & i_rd)
        begin
            fifo_mem[write_cnt] <= i_data;
            fifo_valid_mem[write_cnt] <= i_valid;
            fifo_mem[read_cnt] <= {DATA_WIDTH{1'b0}};
            fifo_valid_mem[read_cnt] <= {VALID_WIDTH{1'b0}};  
        end
        else if(i_en & i_wr)
        begin
            fifo_mem[write_cnt] <= i_data;
            fifo_valid_mem[write_cnt] <= i_valid;
        end
        else if(i_en & i_rd)
        begin
            fifo_mem[read_cnt] <= {DATA_WIDTH{1'b0}};
            fifo_valid_mem[read_cnt] <= {VALID_WIDTH{1'b0}};
        end
        else
        begin
            for(i=0; i< DEPTH; i=i+1)
            begin
                fifo_mem[i] <= fifo_mem[i];
                fifo_valid_mem[i] <= fifo_valid_mem[i];
            end
        end
    end

    /*
        read logic        
    */
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            read_cnt <= {CNT_BIT_WIDTH{1'b0}};
        end
        else if(i_en & i_rd)
        begin
            read_cnt <= read_cnt + 1'b1;
        end
        else
        begin
            read_cnt <= read_cnt;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
        begin
            o_data_inner <= {DATA_WIDTH{1'b0}};
            o_valid_inner <= {VALID_WIDTH{1'b0}};
        end
        else if(i_en & i_rd)
        begin
            o_data_inner <= (read_cnt==(DEPTH-1))? fifo_mem[0] : fifo_mem[read_cnt+1];
            o_valid_inner <= (read_cnt==(DEPTH-1))? fifo_valid_mem[0] : fifo_valid_mem[read_cnt+1];
        end
        else if(i_en & (~i_rd))
        begin
            o_data_inner <= fifo_mem[read_cnt];
            o_valid_inner <= fifo_valid_mem[read_cnt];
        end
        else
        begin
            o_data_inner <= o_data_inner;
            o_valid_inner <= o_valid_inner;
        end
    end

    assign o_data = o_data_inner;
    assign o_valid = o_valid_inner;

endmodule
