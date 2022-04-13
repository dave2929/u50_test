
`timescale 1 ns / 1 ps

`define PERIOD 10

/*
    Top Module:  tb_axis_master_slave_systolic_array_top_AXI_seq
    Data:        Only data width matters.
    Format:      keeping the input format unchange
    Timing:      Sequential Logic
    Dummy Data:  {DATA_WIDTH{1'b0}}

    Function: Receive the data from AXI-STREAM Slave and send it through AXI-STREAM Master 
     __________________________________________        ____________      __________________________________________ 
    | AXI Stream Master Random Data Generation |----->| adder tree |--->| AXI Stream Slave Random Data Generation | 
    |__________________________________________|      |____________|    |_________________________________________| 
                                                   
    Author:      Jianming Tong (jianming.tong@gatech.edu)
*/

module tb_axis_master_slave_systolic_array_top_AXI_seq();
    // Parameters of Axi Slave Bus Interface S00_AXIS
    localparam integer C_S00_AXIS_TDATA_WIDTH	= 128;

    // Parameters of Axi Master Bus Interface M00_AXIS
    localparam integer C_M00_AXIS_TDATA_WIDTH	= 256;
    localparam integer C_M00_AXIS_START_COUNT	= 32;
    localparam integer DATA_WIDTH	= 9;
    localparam integer C_S00_AXIS_STRB_WIDTH	= C_S00_AXIS_TDATA_WIDTH/DATA_WIDTH;
    localparam integer C_M00_AXIS_STRB_WIDTH	= C_M00_AXIS_TDATA_WIDTH/DATA_WIDTH;

    // Ports of Axi Slave Bus Interface S00_AXIS
    reg clk;
    reg rst_n;
    wire s00_axis_tready;
    wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata;
    wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb;
    wire s00_axis_tlast;
    wire s00_axis_tvalid;

    // Ports of Axi Master Bus Interface M00_AXIS
    wire  m00_axis_tvalid;
    wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata;
    wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb;
    wire  m00_axis_tlast;
    wire  m00_axis_tready;

    reg  [C_M00_AXIS_START_COUNT -1:0]  read_pointer;

    // Instantiation of Axi Bus Interface M00_AXIS
    // axis_master_data_gen # ( 
    //     .C_M_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
    //     .C_M_START_COUNT(C_M00_AXIS_START_COUNT)
    // ) axis_master (
    //     .M_AXIS_ACLK(clk),
    //     .M_AXIS_ARESETN(rst_n),
    //     .M_AXIS_TVALID(m00_axis_tvalid),
    //     .M_AXIS_TDATA(m00_axis_tdata),
    //     .M_AXIS_TSTRB(m00_axis_tstrb),
    //     .M_AXIS_TLAST(m00_axis_tlast),
    //     .M_AXIS_TREADY(m00_axis_tready)
    // );
    initial
    begin
        $dumpfile("/home/jimmy/MAERI/MAERI_CPP_Emulator/SystolicArray_Emulator/RTL/Version1_9bit_data/testbench/Single_Tile.vcd");
        $dumpvars(0, dut);
    end

    axis_master_data_gen_mem # ( 
        .C_M_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
        .C_M_START_COUNT(C_M00_AXIS_START_COUNT)
    ) axis_master (
        .m00_axis_aclk(clk),
        .m00_axis_aresetn(rst_n),
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tstrb(m00_axis_tstrb),
        .m00_axis_tlast(m00_axis_tlast),
        .m00_axis_tready(m00_axis_tready)
    );

    systolic_array_top_AXI_seq #(
        .C_S00_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
        .C_M00_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH),
        .C_M00_AXIS_START_COUNT(C_M00_AXIS_START_COUNT),
        .DATA_WIDTH(DATA_WIDTH),
        .C_S00_STRB_WIDTH(C_S00_AXIS_TDATA_WIDTH/8),
        .C_M00_STRB_WIDTH(C_M00_AXIS_TDATA_WIDTH/8)
    ) dut (
        .s00_axis_aclk(clk),
        .s00_axis_aresetn(rst_n), //change this to ~rstn
        .s00_axis_tready(m00_axis_tready),
        .s00_axis_tdata(m00_axis_tdata),
        .s00_axis_tstrb(m00_axis_tstrb),
        .s00_axis_tlast(m00_axis_tlast),
        .s00_axis_tvalid(m00_axis_tvalid),

        // Ports of Axi Master Bus Interface M00_AXIS
        .m00_axis_aclk(clk),
        .m00_axis_aresetn(rst_n),
        .m00_axis_tvalid(s00_axis_tvalid),
        .m00_axis_tdata(s00_axis_tdata),
        .m00_axis_tstrb(s00_axis_tstrb),
        .m00_axis_tlast(s00_axis_tlast),
        .m00_axis_tready(s00_axis_tready)
    );

    always@(posedge clk)
    begin
        if(m00_axis_tready & m00_axis_tvalid)
        begin
            read_pointer <= read_pointer + 1'b1;
        end
    end

    // Instantiation of Axi Bus Interface S00_AXIS
    axis_slave_data_rec_test # ( 
        .C_S_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH)
    ) axis_slave (
        .S_AXIS_ACLK(clk),
        .S_AXIS_ARESETN(rst_n),
        .S_AXIS_TREADY(s00_axis_tready),
        .S_AXIS_TDATA(s00_axis_tdata),
        .S_AXIS_TSTRB(s00_axis_tstrb),
        .S_AXIS_TLAST(s00_axis_tlast),
        .S_AXIS_TVALID(s00_axis_tvalid)
    );

    // Add user logic here
    // User logic ends
    initial begin
        clk=0;
        read_pointer = 0;
        rst_n = 1;
        
        #(`PERIOD)
        rst_n = 0;
        
        #(`PERIOD)
        rst_n = 1;

        #(32*`PERIOD)
        #(8*`PERIOD)
        #(32*`PERIOD)
        #(8*`PERIOD)
        #(10*`PERIOD)
        #(10*`PERIOD)
        #(250*`PERIOD)
        #(100*`PERIOD)
        #(50*`PERIOD)
        $stop;
    end

    always#(`PERIOD/2) clk = ~clk;

    always@(posedge clk) begin
        // $display("data gen sends %d-th data\n", read_pointer);
        // $display("data gen sends %d-th data\n", read_pointer);
    end

endmodule
