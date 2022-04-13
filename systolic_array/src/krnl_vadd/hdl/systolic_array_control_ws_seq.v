`timescale 1ns / 1ps

/*
    Top Module:  systolic_array_control_ws_seq
    Data:        Only data width matters.
    Format:      Output has 1 more bit than input
    Timing:      Sequential Logic
    Reset:       Asynchronized Reset [Low Reset]
    Dummy Data:  {DATA_WIDTH{1'b0}}

    Function: Multiple data bus are time division multiplexing the same external data bus,
              this FSM is proposed to control the switching.

    Author:      Yangyu Chen (yangyuchen@gatech.edu), Jianming TONG (jianming.tong@gatech.edu)
*/

module systolic_array_control_ws_seq #(
    parameter WEIGHTS_CYCLE = 8,
    parameter DATAPATH_LATENCY = 17,
    parameter NUM_COL = 8
) (
    clk,
    rst_n,

    i_valid,
    i_last,
    o_cmd
);

    localparam STATE_WIDTH = 2;
	localparam WEIGHTS = 2'b00;
	localparam DATA_STREAM = 2'b01;
	localparam WAIT_INPUT_FINISH = 2'b10; // the last input needs 17 cycles to pass over the array.

    input                               clk;
    input                               rst_n;
    input                               i_valid;
    input                               i_last;

    output                              o_cmd;

    /*
        Inner parameter
    */
    reg                                 o_cmd_inner;
    
    /*
        state machine
    */
    reg [STATE_WIDTH - 1 : 0]	        cs;
	reg [STATE_WIDTH - 1 : 0]           ns;
	reg [$clog2(WEIGHTS_CYCLE): 0]      cnt_weight;
	reg [$clog2(DATAPATH_LATENCY): 0]   cnt_end;

    always @(*) begin
        case(cs)
            WEIGHTS: 
            if (cnt_weight == WEIGHTS_CYCLE - 1) begin
            	ns = DATA_STREAM;
            end
            else
            begin
            	ns = WEIGHTS;
            end     
            DATA_STREAM: 
            if (i_last)
            begin
                ns = WAIT_INPUT_FINISH;
            end
            else
            begin
                ns = DATA_STREAM;
            end
            WAIT_INPUT_FINISH:
            begin
                if (cnt_end == DATAPATH_LATENCY - 1) begin
                    ns = WEIGHTS;
                end
                else
                begin
            	    ns = WAIT_INPUT_FINISH;
                end
            end
            default: ns = WEIGHTS;
        endcase
	end

	always @(posedge clk or negedge rst_n) begin
		if (~rst_n)
		begin
			cs <= WEIGHTS;
		end
		else
		begin
            cs <= ns;
		end
	end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
        begin
            cnt_weight <= 0;
        end
        else if ((cs == WEIGHTS) && i_valid)
        begin
            cnt_weight <= cnt_weight + 1'b1;
        end
        else if (cs == WEIGHTS && ~(i_valid))
        begin
            cnt_weight <= cnt_weight;
        end
        else
        begin
            cnt_weight <= 0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n)
        begin
            cnt_end <= 0;
        end
        else if (cs == WAIT_INPUT_FINISH)
        begin
            cnt_end <= cnt_end + 1'b1;
        end
        else
        begin
            cnt_end <= 0;
        end
    end
  
    always @(*) begin
        if(cs == WEIGHTS)
        begin
            o_cmd_inner <= 1'b1;
        end
        else
        begin
            o_cmd_inner <= 1'b0;
        end
    end

    assign o_cmd = o_cmd_inner;

endmodule
