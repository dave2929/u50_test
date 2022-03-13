
`timescale 1 ns / 1 ps

module axis_master_data_gen_mem#
(
    parameter integer C_M_AXIS_TDATA_WIDTH	= 32,
    parameter integer C_M_START_COUNT	= 32
)
(
    m00_axis_aclk,
    m00_axis_aresetn,
    m00_axis_tvalid,
    m00_axis_tdata,
    m00_axis_tstrb,
    m00_axis_tlast,
    m00_axis_tready
);
    input                                              m00_axis_aclk;
    input                                              m00_axis_aresetn;
    output   [1:0]                                     m00_axis_tvalid;
    output   [C_M_AXIS_TDATA_WIDTH-1 : 0]              m00_axis_tdata;
    output   [(C_M_AXIS_TDATA_WIDTH/8)-1 : 0]          m00_axis_tstrb;
    output                                             m00_axis_tlast;
    input                                              m00_axis_tready;

    /*
        User controlled parameters
    */
    // localparam NUMBER_OF_OUTPUT_WORDS = 100;//261;
    localparam NUMBER_OF_OUTPUT_WORDS = 10;//261;
    localparam OUTPUT_WORD_ID_STALL_FOR_50_CYCLE = NUMBER_OF_OUTPUT_WORDS;//261;

    function integer clogb2 (input integer bit_depth);
        begin
            for(clogb2=0; bit_depth>0; clogb2=clogb2+1)
                bit_depth = bit_depth >> 1;
        end
    endfunction

    reg [$clog2(NUMBER_OF_OUTPUT_WORDS)-1:0]           read_pointer;
    reg [C_M_AXIS_TDATA_WIDTH-1:0]                     m00_axis_tdata_inner;
    reg [1:0]                                          m00_axis_tvalid_inner;
    wire                                               send_tx;
    assign    send_tx = m00_axis_tvalid_inner & m00_axis_tready;
    reg                                                tx_done;
    reg                                                no_send;
    reg      [$clog2(NUMBER_OF_OUTPUT_WORDS)-1:0]      stall_cnt;

    reg      [C_M_AXIS_TDATA_WIDTH-1:0]                mem[0:9];
    initial
    begin
        stall_cnt <= 0;
        mem[0] = 64'b0000000000000000000000000000000100000000000000000000000000000001;
        mem[1] = 64'b0000000000000000000000000000001100000000000000000000000000000011;
        mem[2] = 64'b0000000000000000000000000000011100000000000000000000000000000111;
        mem[3] = 64'b0000000000000000000000000000001100000000000000000000000000000011;
        mem[4] = 64'b0000000000000000000000000000000100000000000000000000000000000001;
        mem[5] = 64'b0000000000000000000000000000001100000000000000000000000000000011;
        mem[6] = 64'b0000000000000000000000000000011100000000000000000000000000000111;
        mem[7] = 64'b0000000000000000000000000000001100000000000000000000000000000011;
        mem[8] = 64'b0000000000000000000000000000000100000000000000000000000000000001;
        mem[9] = 64'b0000000000000000000000000000001100000000000000000000000000000011;
        
    end

    // read_pointer pointer
    always@(posedge m00_axis_aclk)
    begin
        if(!m00_axis_aresetn)
        begin
            read_pointer <= 0;
        end
        else if(send_tx)
        begin
            read_pointer <= read_pointer + 1'b1;
        end
        else
        begin
            read_pointer <= read_pointer;
        end
    end

    // stall counter increase
    always@(posedge m00_axis_aclk)
    begin
        if(!m00_axis_aresetn)
        begin
            stall_cnt <= 0;
        end
        else if(read_pointer >= (OUTPUT_WORD_ID_STALL_FOR_50_CYCLE - 1))
        begin
            stall_cnt <= stall_cnt + 1'b1;
        end
        else
        begin
            stall_cnt <= stall_cnt;
        end
    end

    always@(posedge m00_axis_aclk)
    begin
        if(!m00_axis_aresetn)
        begin
            m00_axis_tvalid_inner <= 2'b11;
        end
        else if (read_pointer == (OUTPUT_WORD_ID_STALL_FOR_50_CYCLE-1) && (stall_cnt < 50))
        begin
            m00_axis_tvalid_inner <= 2'b00;
        end
        else if (read_pointer == (OUTPUT_WORD_ID_STALL_FOR_50_CYCLE) && (stall_cnt >= 50))
        begin    
            m00_axis_tvalid_inner <= 2'b11;
        end
        else if(read_pointer == (NUMBER_OF_OUTPUT_WORDS-1))
        begin
            m00_axis_tvalid_inner <= 2'b00;
        end
        else
        begin
            m00_axis_tvalid_inner <= m00_axis_tvalid_inner;
        end
    end

    // read_pointer pointer
    always@(posedge m00_axis_aclk)
    begin
        if(!m00_axis_aresetn)
        begin
            no_send <= 1'b0;
        end
        else if (read_pointer == (OUTPUT_WORD_ID_STALL_FOR_50_CYCLE - 1) && (stall_cnt < 50))
        begin    
            no_send <= 1'b1;
        end
        else if (read_pointer == (OUTPUT_WORD_ID_STALL_FOR_50_CYCLE) && (stall_cnt >= 50))
        begin    
            no_send <= 1'b0;
        end
        else if (read_pointer == (NUMBER_OF_OUTPUT_WORDS-1))
        begin    
            no_send <= 1'b1;
        end
        else
        begin
            no_send <= no_send;
        end
    end

    // always@(posedge m00_axis_aclk)
    // begin
    //     if(!m00_axis_aresetn)
    //     begin
    //         m00_axis_tvalid_inner <= 1'b1;
    //     end
    //     else if(read_pointer == (NUMBER_OF_OUTPUT_WORDS-1))
    //     begin
    //         m00_axis_tvalid_inner <= 1'b0;
    //     end
    //     else
    //     begin
    //         m00_axis_tvalid_inner <= m00_axis_tvalid_inner;
    //     end
    // end

    // //read_pointer pointer
    // always@(posedge m00_axis_aclk)
    // begin
    //     if(!m00_axis_aresetn)
    //     begin
    //         no_send <= 1'b0;
    //     end
    //     else if (read_pointer == (NUMBER_OF_OUTPUT_WORDS-1))
    //     begin    
    //         no_send <= 1'b1;
    //     end
    //     else
    //     begin
    //         no_send <= no_send;
    //     end
    // end

    // read_pointer pointer
    always@(*)
    begin
        if(!m00_axis_aresetn)
        begin
            tx_done <= 1'b0;
        end
        else if (read_pointer == (NUMBER_OF_OUTPUT_WORDS-1))
        begin    
            tx_done <= 1'b1;
        end
        else
        begin
            tx_done <= 1'b0;
        end
    end

    // Streaming output data is read from FIFO
    always @(*)
    begin
        if(!m00_axis_aresetn)
        begin
            m00_axis_tdata_inner <= mem[0];
        end
        else if(no_send)
        begin
            m00_axis_tdata_inner <= 0;
        end
        else
        begin
            m00_axis_tdata_inner <= mem[read_pointer]; //read_pointer + 32'b1;
        end
    end

    assign  m00_axis_tvalid = m00_axis_tvalid_inner;
    assign  m00_axis_tdata = m00_axis_tdata_inner;
    assign  m00_axis_tstrb = {(C_M_AXIS_TDATA_WIDTH/8){m00_axis_tvalid_inner}};
    assign  m00_axis_tlast = tx_done;

endmodule
