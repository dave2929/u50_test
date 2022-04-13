`timescale 1ns / 1ps
/*
    Top Module:  systolic_array_top_AXI_seq
    Data:        Only data width matters.
    Format:      keeping the input format unchange
    Timing:      Sequential Logic
    Dummy Data:  {DATA_WIDTH{1'b0}}

    Function:    Receive the data from AXI-STREAM Slave and send it through AXI-STREAM Master
    
    Note:        MODULE_LATENCY should be exact the latency of hardware in cycle.
                 Such parameter is used to 
                 1. control the back pressure (no valid data replacement in output_fifo)
                 2. control the t_last signal (not appear too early)

    Author:      Jianming Tong (jianming.tong@gatech.edu)
*/

module systolic_array_top_AXI_seq #(
    // Parameters of Axi Slave Bus Interface S00_AXIS
    parameter C_S00_AXIS_TDATA_WIDTH	= 128,

    // Parameters of Axi Master Bus Interface M00_AXIS
    parameter C_M00_AXIS_TDATA_WIDTH	= 256,
    parameter C_M00_AXIS_START_COUNT	= 32,
    parameter DATA_WIDTH = 9,
    parameter C_S00_STRB_WIDTH = C_S00_AXIS_TDATA_WIDTH/8,
    parameter C_M00_STRB_WIDTH = C_M00_AXIS_TDATA_WIDTH/8
)
(
    // Ports of Axi Slave Bus Interface S00_AXIS
    s00_axis_aclk,
    s00_axis_aresetn,
    s00_axis_tready,
    s00_axis_tdata,
    s00_axis_tstrb,
    s00_axis_tlast,
    s00_axis_tvalid,

    // Ports of Axi Master Bus Interface M00_AXIS
    m00_axis_aclk,
    m00_axis_aresetn,
    m00_axis_tvalid,
    m00_axis_tdata,
    m00_axis_tstrb,
    m00_axis_tlast,
    m00_axis_tready
);

// tstrb -> high
// tlast jiechuqu

    /*
        tunable parameter
    */
    // localparam DATA_WIDTH = 8;
    localparam NUM_DATA_IN_BUF = 32;
    localparam MODULE_LATENCY = 18; // (should be smaller than the largest latency)
    localparam BUF_LATENCY = 1;     // buffer has 1 cycles latency.

    /*
        local parameters
    */
    localparam CNT_VALID_WIDTH =  1 + $clog2(NUM_DATA_IN_BUF);
    localparam CUT_OFF_THRESHOLD = NUM_DATA_IN_BUF - MODULE_LATENCY - BUF_LATENCY - 1; // start to cut off when the last empty slot remain

    /*
        input & output ports
    */
    input                                              s00_axis_aclk;
    input                                              s00_axis_aresetn;
    output                                             s00_axis_tready;
    input    [C_S00_AXIS_TDATA_WIDTH-1 : 0]            s00_axis_tdata;
    input    [C_S00_STRB_WIDTH-1 : 0]                  s00_axis_tstrb;
    input                                              s00_axis_tlast;
    input                                              s00_axis_tvalid;

    input                                              m00_axis_aclk;
    input                                              m00_axis_aresetn;
    output                                             m00_axis_tvalid;
    output   [C_M00_AXIS_TDATA_WIDTH-1 : 0]            m00_axis_tdata;
    output   [C_M00_STRB_WIDTH-1 : 0]                  m00_axis_tstrb;
    output                                             m00_axis_tlast;
    input                                              m00_axis_tready;

    /*
        protocol register
    */
    reg                                                s00_axis_tready_inner;
    reg                                                m00_axis_tvalid_inner;

    /*
        User parameter
    */
    localparam NUM_ROW = 8;
    localparam NUM_COL = 8;

    /*
        User register
    */
    reg i_wr_ctrl;

    /*
        inner register
    */
    reg                                                m00_axis_tlast_inner;
    reg                                                s00_axis_tlast_inner;
    wire                                               last_data_ready;

    reg      [CNT_VALID_WIDTH-1 : 0]                   cnt_valid_data;
    reg      [CNT_VALID_WIDTH-1 : 0]                   cnt_last_data_show;

    wire     [NUM_COL - 1 : 0]                         o_valid_inner;
    reg                                                i_en;

    initial begin
        i_en = 1'b1;
    end

    /*
        intermediate wire -- ease for programing
    */
    wire axi_slave_protocol_valid;
    wire [C_S00_STRB_WIDTH-1:0] i_valid_mask; 
    wire [C_S00_STRB_WIDTH-1:0] i_valid_signal; 

    assign axi_slave_protocol_valid = s00_axis_tvalid & s00_axis_tready_inner;
    assign i_valid_mask = {C_S00_STRB_WIDTH{axi_slave_protocol_valid}};
    assign i_valid_signal = i_valid_mask & s00_axis_tstrb;

    assign last_data_ready = s00_axis_tlast_inner && (cnt_last_data_show >= MODULE_LATENCY + BUF_LATENCY);

    ///////////////////////// Control Block
    /*
        control block template - receive data
    */
    always @(posedge s00_axis_aclk) begin
        if(!s00_axis_aresetn)
        begin
            s00_axis_tready_inner <= 1'b0;
        end
        else if ((cnt_valid_data>=CUT_OFF_THRESHOLD) & m00_axis_tvalid_inner & m00_axis_tready & s00_axis_tvalid)
        begin
            s00_axis_tready_inner <= 1'b1;
        end
        else if ((cnt_valid_data>=CUT_OFF_THRESHOLD) & (~(m00_axis_tvalid_inner & m00_axis_tready)) & s00_axis_tvalid)
        begin
            s00_axis_tready_inner <= 1'b0;
        end
        else if( (cnt_valid_data<CUT_OFF_THRESHOLD) & s00_axis_tvalid )
        begin
            s00_axis_tready_inner <= 1'b1;
        end
        else
        begin
            s00_axis_tready_inner <= 1'b0;
        end
    end

    /*
        control block template - send data
    */
    always @(posedge s00_axis_aclk) begin
        if(!s00_axis_aresetn)
        begin
            m00_axis_tvalid_inner <= 1'b0;
        end
        else if((cnt_valid_data > {{(CNT_VALID_WIDTH-1){1'b0}},{1'b1}})) // when buffer have more than 1 data (at least 2 data), valid must be asserted as 1.
        begin
            m00_axis_tvalid_inner <= 1'b1;
        end
        else if((cnt_valid_data == {{(CNT_VALID_WIDTH-1){1'b0}},{1'b1}}) & last_data_ready &  (~m00_axis_tvalid_inner) & m00_axis_tready) // must be asserted as high when tlast is gonna be asserted as high.
        begin
            m00_axis_tvalid_inner <= 1'b1;
        end
        else if(m00_axis_tlast_inner)
        begin
            m00_axis_tvalid_inner <= 1'b0;
        end
        else
        begin
            m00_axis_tvalid_inner <= 1'b0;
        end
    end

    /*
        control block template - m00_axis_tlast
    */
    always @(posedge s00_axis_aclk) begin
        if(!s00_axis_aresetn)
        begin
            cnt_last_data_show <= 0;
        end
        else if(((s00_axis_tlast && axi_slave_protocol_valid)|| cnt_last_data_show > 0) && (cnt_last_data_show < (MODULE_LATENCY + BUF_LATENCY)))
        begin
            cnt_last_data_show <= cnt_last_data_show + 1'b1;
        end
        else if (m00_axis_tlast_inner)
        begin
            cnt_last_data_show <= 0;
        end
        else
        begin
            cnt_last_data_show <= cnt_last_data_show;
        end
    end

    always@(posedge s00_axis_aclk)begin
        if(!s00_axis_aresetn)
        begin
            s00_axis_tlast_inner <= 1'b0;
        end
        else if(s00_axis_tlast)
        begin
            s00_axis_tlast_inner <= s00_axis_tlast;
        end
        else if(m00_axis_tlast_inner)
        begin
            s00_axis_tlast_inner <= 1'b0;
        end
        else
        begin
            s00_axis_tlast_inner <= s00_axis_tlast_inner;
        end
    end

    always @(posedge s00_axis_aclk) begin
        if(!s00_axis_aresetn)
        begin
            m00_axis_tlast_inner <= 1'b0;
        end
        else if( last_data_ready & m00_axis_tvalid_inner & m00_axis_tready & (cnt_valid_data == 2'b10))      // in the consecutive data stream, predict next cycle is the last data
        begin
            m00_axis_tlast_inner <= 1'b1;
        end
        else if( last_data_ready &  (~m00_axis_tvalid_inner) & m00_axis_tready & (cnt_valid_data == 1'b1)) // in the stop data stream (no data is transferred now), still have the last data in need of transfer
        begin
            m00_axis_tlast_inner <= 1'b1;
        end
        else
        begin
            m00_axis_tlast_inner <= 1'b0;
        end
    end

    /*
        control block template - cnt_valid_data
    */
    always @(posedge s00_axis_aclk) begin
        if(!s00_axis_aresetn)
        begin
            cnt_valid_data <= {CNT_VALID_WIDTH{1'b0}};
        end
        else if(i_wr_ctrl & m00_axis_tvalid_inner & m00_axis_tready)
        begin
            cnt_valid_data <= cnt_valid_data;
        end
        else if(i_wr_ctrl & (~(m00_axis_tvalid_inner & m00_axis_tready)) )
        begin
            cnt_valid_data <= cnt_valid_data + {{(CNT_VALID_WIDTH-1){1'b0}},{1'b1}};
        end
        else if( (~i_wr_ctrl) & m00_axis_tvalid_inner & m00_axis_tready )
        begin
            cnt_valid_data <= cnt_valid_data - {{(CNT_VALID_WIDTH-1){1'b0}},{1'b1}};
        end
        else
        begin
            cnt_valid_data <= cnt_valid_data;
        end
    end


    ///////////////////////// Datapath
    /*
        User Parameter
    */
    localparam  NUM_REC_DATA = NUM_ROW * DATA_WIDTH; 
    localparam  OUT_DATA_WIDTH = NUM_ROW * ((DATA_WIDTH << 1) + NUM_ROW - 1); 
    localparam  PAD_ZERO = C_M00_AXIS_TDATA_WIDTH - OUT_DATA_WIDTH; 
    reg         [PAD_ZERO-1:0]                          zero_pad;
    wire        [C_M00_AXIS_TDATA_WIDTH-1:0]            out_dut_in_fifo;
    wire        [OUT_DATA_WIDTH-1:0]                    o_data_inner;

    initial begin
        zero_pad = {PAD_ZERO{1'b0}};
    end

    /*
        User defined module
    */
    always @(*) begin
        i_wr_ctrl <= (o_valid_inner > 0)?1'b1:1'b0;
    end

    systolic_array_top_ws_seq#(
        .NUM_ROW(NUM_ROW),
        .NUM_COL(NUM_COL),
        .DATA_WIDTH(DATA_WIDTH)
    )dut(
        .clk(s00_axis_aclk),
        .rst_n(s00_axis_aresetn),
        .i_data(s00_axis_tdata[NUM_REC_DATA-1:0]),    // top input ports
        .i_valid(i_valid_signal[NUM_ROW-1:0]),        // input valid
        .i_last(s00_axis_tlast),                      // last input data
        .o_data(o_data_inner),                        // change i_data to weights
        .o_valid(o_valid_inner)                       // output valid
    );

    assign out_dut_in_fifo[C_M00_AXIS_TDATA_WIDTH-1:OUT_DATA_WIDTH] = zero_pad;
    assign out_dut_in_fifo[OUT_DATA_WIDTH-1:0] = o_data_inner;
    
    /*
        receive buffer
    */
    fifo_seq_top_always_appear_simple_seq#(
        .DATA_WIDTH(C_M00_AXIS_TDATA_WIDTH),
        .VALID_WIDTH(C_M00_STRB_WIDTH),
        .DEPTH(NUM_DATA_IN_BUF))
    axis_out_fifo(
        .clk(m00_axis_aclk),
        .rst_n(m00_axis_aresetn),
        .i_data(out_dut_in_fifo),
        .i_valid({C_M00_STRB_WIDTH{i_wr_ctrl}}),
        .o_data(m00_axis_tdata),
        .o_valid(m00_axis_tstrb),
        .i_en(i_en),
        .i_rd(m00_axis_tvalid_inner & m00_axis_tready),
        .i_wr(i_wr_ctrl)
    );

    /*
        output wire connection
    */
    assign s00_axis_tready = s00_axis_tready_inner;
    assign m00_axis_tvalid = m00_axis_tvalid_inner;
    assign m00_axis_tlast = m00_axis_tlast_inner;

endmodule
