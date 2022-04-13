
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

module tb_hls_axis_systolic_array();
    // Parameters of Axi Slave Bus Interface S00_AXIS
    localparam integer C_S00_AXIS_TDATA_WIDTH	= 128;
    localparam integer C_M_AXI_GMEM_DATA_WIDTH	= 128;
    localparam integer C_S_AXI_GMEM_DATA_WIDTH	= 256;

    // Parameters of Axi Master Bus Interface M00_AXIS
    localparam integer C_M00_AXIS_TDATA_WIDTH	= 256;
    localparam integer C_M00_AXIS_START_COUNT	= 32;
    localparam integer DATA_WIDTH	= 9;
    localparam integer C_S00_AXIS_STRB_WIDTH	= C_S00_AXIS_TDATA_WIDTH/DATA_WIDTH;
    localparam integer C_M00_AXIS_STRB_WIDTH	= C_M00_AXIS_TDATA_WIDTH/DATA_WIDTH;

    localparam integer LP_NUM_READ_CHANNELS  = 1;
    localparam integer LP_LENGTH_WIDTH       = 32;
    localparam integer LP_DW_BYTES           = C_M_AXI_GMEM_DATA_WIDTH/8;
    localparam integer LP_AXI_BURST_LEN      = 4096/LP_DW_BYTES < 256 ? 4096/LP_DW_BYTES : 256;
    localparam integer LP_LOG_BURST_LEN      = $clog2(LP_AXI_BURST_LEN);
    localparam integer LP_RD_MAX_OUTSTANDING = 3;
    localparam integer LP_RD_FIFO_DEPTH      = LP_AXI_BURST_LEN*(LP_RD_MAX_OUTSTANDING + 1);
    localparam integer LP_WR_FIFO_DEPTH      = LP_AXI_BURST_LEN;

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

    // FIFO parameters
    logic [LP_NUM_READ_CHANNELS-1:0] ctrl_rd_fifo_prog_full;
    logic [LP_NUM_READ_CHANNELS-1:0] rd_fifo_tvalid_n;
    logic [LP_NUM_READ_CHANNELS-1:0] rd_fifo_tready; 
    logic [LP_NUM_READ_CHANNELS-1:0] rd_fifo_tlast; 
    logic [LP_NUM_READ_CHANNELS-1:0] [C_M_AXI_GMEM_DATA_WIDTH-1:0] rd_fifo_tdata;
    logic [LP_NUM_READ_CHANNELS-1:0] [(C_M_AXI_GMEM_DATA_WIDTH/8)-1:0] rd_fifo_tstrb;

    logic                               systolic_tvalid;
    logic                               systolic_tready_n; 
    logic [C_M00_AXIS_TDATA_WIDTH-1:0]  systolic_tdata;
    logic [(C_M00_AXIS_TDATA_WIDTH/8)-1:0]  systolic_tstrb;
    logic                               systolic_tlast;
    logic                               wr_fifo_tvalid_n;
    logic                               wr_fifo_tready; 
    logic [C_M00_AXIS_TDATA_WIDTH-1:0]  wr_fifo_tdata;
    logic                               wr_fifo_tlast;

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
        .m00_axis_tready(~m00_axis_tready)
    );
        
    xpm_fifo_sync # (
        .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
        .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
        .FIFO_WRITE_DEPTH          (LP_RD_FIFO_DEPTH),   //positive integer
        .WRITE_DATA_WIDTH          (C_M_AXI_GMEM_DATA_WIDTH),        //positive integer
        .WR_DATA_COUNT_WIDTH       ($clog2(LP_RD_FIFO_DEPTH)+1),       //positive integer, Not used
        .PROG_FULL_THRESH          (LP_AXI_BURST_LEN-2),               //positive integer
        .FULL_RESET_VALUE          (1),                //positive integer; 0 or 1
        .READ_MODE                 ("fwft"),            //string; "std" or "fwft";
        .FIFO_READ_LATENCY         (1),                //positive integer;
        .READ_DATA_WIDTH           (C_M_AXI_GMEM_DATA_WIDTH),               //positive integer
        .RD_DATA_COUNT_WIDTH       ($clog2(LP_RD_FIFO_DEPTH)+1),               //positive integer, not used
        .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
        .DOUT_RESET_VALUE          ("0"),              //string, don't care
        .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;

    ) inst_rd_xpm_fifo_sync[LP_NUM_READ_CHANNELS-1:0] (
        .sleep         ( 1'b0             ) ,
        .rst           ( ~rst_n           ) ,
        .wr_clk        ( clk           ) ,
        .wr_en         ( m00_axis_tvalid        ) ,
        .din           ( m00_axis_tdata         ) ,
        .full          ( m00_axis_tready      ) ,
        .prog_full     ( ctrl_rd_fifo_prog_full) ,
        .wr_data_count (                  ) ,
        .overflow      (                  ) ,
        .wr_rst_busy   (                  ) ,
        .rd_en         ( rd_fifo_tready   ) ,
        .dout          ( rd_fifo_tdata    ) ,
        .empty         ( rd_fifo_tvalid_n ) ,
        .prog_empty    (                  ) ,
        .rd_data_count (                  ) ,
        .underflow     (                  ) ,
        .rd_rst_busy   (                  ) ,
        .injectsbiterr ( 1'b0             ) ,
        .injectdbiterr ( 1'b0             ) ,
        .sbiterr       (                  ) ,
        .dbiterr       (                  ) 

    );

    always @(posedge clk) begin
        for (int i = 0; i < LP_NUM_READ_CHANNELS; i++) begin
            rd_fifo_tlast[i] <= m00_axis_tlast;
            // rd_fifo_tlast[i] <= 1'b0;
        end
    end

    always_comb begin
        for (int i = 0; i < LP_NUM_READ_CHANNELS; i++) begin
            rd_fifo_tstrb[i] = {(C_M_AXI_GMEM_DATA_WIDTH/8){1'b1}};
        end
    end

    assign systolic_tstrb = {(C_M00_AXIS_TDATA_WIDTH/8){1'b1}};


    systolic_array_top_AXI_seq #(
        .C_S00_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH),
        .C_M00_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH),
        .C_M00_AXIS_START_COUNT(C_M00_AXIS_START_COUNT),
        .DATA_WIDTH(DATA_WIDTH),
        .C_S00_STRB_WIDTH(C_S00_AXIS_TDATA_WIDTH/8),
        .C_M00_STRB_WIDTH(C_M00_AXIS_TDATA_WIDTH/8)
    ) dut (
        .s00_axis_aclk(clk),
        .s00_axis_aresetn(rst_n), // active-low areset
        .s00_axis_tready(rd_fifo_tready),
        .s00_axis_tdata(rd_fifo_tdata),
        .s00_axis_tstrb(rd_fifo_tstrb),
        .s00_axis_tlast(rd_fifo_tlast),
        .s00_axis_tvalid(~rd_fifo_tvalid_n),

        // Ports of Axi Master Bus Interface M00_AXIS
        .m00_axis_aclk(clk),
        .m00_axis_aresetn(rst_n),
        .m00_axis_tvalid(systolic_tvalid),
        .m00_axis_tdata(systolic_tdata),
        .m00_axis_tstrb(systolic_tstrb),
        .m00_axis_tlast(systolic_tlast),
        .m00_axis_tready(~systolic_tready_n)
    );

    always@(posedge clk)
    begin
        if(m00_axis_tready & m00_axis_tvalid)
        begin
            read_pointer <= read_pointer + 1'b1;
        end
    end

    always @(posedge clk) begin
        wr_fifo_tlast <= systolic_tlast;
    end

    xpm_fifo_sync # (
        .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
        .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
        .FIFO_WRITE_DEPTH          (LP_WR_FIFO_DEPTH),   //positive integer
        .WRITE_DATA_WIDTH          (C_S_AXI_GMEM_DATA_WIDTH),               //positive integer
        .WR_DATA_COUNT_WIDTH       ($clog2(LP_WR_FIFO_DEPTH)),               //positive integer, Not used
        .PROG_FULL_THRESH          (10),               //positive integer, Not used 
        .FULL_RESET_VALUE          (1),                //positive integer; 0 or 1
        .READ_MODE                 ("fwft"),            //string; "std" or "fwft";
        .FIFO_READ_LATENCY         (1),                //positive integer;
        .READ_DATA_WIDTH           (C_S_AXI_GMEM_DATA_WIDTH),               //positive integer
        .RD_DATA_COUNT_WIDTH       ($clog2(LP_WR_FIFO_DEPTH)),               //positive integer, not used
        .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
        .DOUT_RESET_VALUE          ("0"),              //string, don't care
        .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;

    ) inst_wr_xpm_fifo_sync (
        .sleep         ( 1'b0             ) ,
        .rst           ( ~rst_n           ) ,
        .wr_clk        ( clk           ) ,
        .wr_en         ( systolic_tvalid     ) ,
        .din           ( systolic_tdata      ) ,
        .full          ( systolic_tready_n   ) ,
        .prog_full     (                  ) ,
        .wr_data_count (                  ) ,
        .overflow      (                  ) ,
        .wr_rst_busy   (                  ) ,
        .rd_en         ( wr_fifo_tready   ) ,
        .dout          ( wr_fifo_tdata    ) ,
        .empty         ( wr_fifo_tvalid_n ) ,
        .prog_empty    (                  ) ,
        .rd_data_count (                  ) ,
        .underflow     (                  ) ,
        .rd_rst_busy   (                  ) ,
        .injectsbiterr ( 1'b0             ) ,
        .injectdbiterr ( 1'b0             ) ,
        .sbiterr       (                  ) ,
        .dbiterr       (                  ) 

    );

    // Instantiation of Axi Bus Interface S00_AXIS
    axis_slave_data_rec_test # ( 
        .C_S_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH)
    ) axis_slave (
        .S_AXIS_ACLK(clk),
        .S_AXIS_ARESETN(rst_n),
        .S_AXIS_TREADY(wr_fifo_tready),
        .S_AXIS_TDATA(wr_fifo_tdata),
        .S_AXIS_TSTRB(systolic_tstrb),
        .S_AXIS_TLAST(wr_fifo_tlast),
        .S_AXIS_TVALID(~wr_fifo_tvalid_n)
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
