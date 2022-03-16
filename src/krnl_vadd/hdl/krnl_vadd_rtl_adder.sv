/**
* Copyright (C) 2019-2021 Xilinx, Inc
*
* Licensed under the Apache License, Version 2.0 (the "License"). You may
* not use this file except in compliance with the License. A copy of the
* License is located at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
* WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
* License for the specific language governing permissions and limitations
* under the License.
*/

////////////////////////////////////////////////////////////////////////////////
// Description: Basic Adder, no overflow. Unsigned. Combinatorial.
////////////////////////////////////////////////////////////////////////////////

`default_nettype none

module krnl_vadd_rtl_adder #(
  parameter integer C_DATA_WIDTH   = 32, // Data width of both input and output data
  parameter integer C_NUM_CHANNELS = 2   // Number of input channels.  Only a value of 2 implemented.
)
(
  input wire                                         aclk,
  input wire                                         areset,

  input wire  [C_NUM_CHANNELS-1:0]                   s_tvalid,
  input wire  [C_NUM_CHANNELS-1:0][C_DATA_WIDTH-1:0] s_tdata,
  output wire [C_NUM_CHANNELS-1:0]                   s_tready,

  output wire                                        m_tvalid,
  output wire [C_DATA_WIDTH-1:0]                     m_tdata,
  input  wire                                        m_tready

);

timeunit 1ps; 
timeprecision 1ps; 


localparam NUM_DATA_IN_BUF = 1; //
localparam CNT_VALID_WIDTH =  1 + $clog2(NUM_DATA_IN_BUF);
localparam CUT_OFF_THRESHOLD = 1;

logic [C_DATA_WIDTH:0] m_tdata_inner;
logic [C_DATA_WIDTH:0] m_tdata_buffer;
logic m_tvalid_inner;
logic m_tvalid_buffer;
logic cnt; // number of data in buffer
logic [C_NUM_CHANNELS-1:0] s_tready_inner;


always @(posedge aclk) begin
  if (!areset)
    cnt <= 1'b0;
  else if ((&s_tready_inner) & (&s_tvalid) & m_tready)
    cnt <= cnt;
  else if ((&s_tready_inner) & ((&s_tvalid) & ~m_tready))
    cnt <= cnt + {{(CNT_VALID_WIDTH-1){1'b0}},{1'b1}};  
  else if ((&s_tready_inner) & (~(&s_tvalid) & m_tready))
    cnt <= cnt;
  else if (~(&s_tready_inner) & m_tready)
    cnt <= cnt == 1'b0 ? 1'b0 : cnt - {{(CNT_VALID_WIDTH-1){1'b0}},{1'b1}};  
  else
    cnt <= cnt;
end

always @(*) begin
  if (!areset)
    s_tready_inner = {C_NUM_CHANNELS{1'b0}};
  if ((cnt >= CUT_OFF_THRESHOLD) & m_tready & m_tvalid_buffer & (&s_tvalid))
    s_tready_inner = {C_NUM_CHANNELS{1'b1}};
  else if ((cnt >= CUT_OFF_THRESHOLD) & (~(m_tready & m_tvalid_buffer)) & (&s_tvalid))
    s_tready_inner = {C_NUM_CHANNELS{1'b0}}; 
  else if ((cnt < CUT_OFF_THRESHOLD) & (&s_tvalid))
    s_tready_inner = {C_NUM_CHANNELS{1'b1}};
  else
    s_tready_inner = {C_NUM_CHANNELS{1'b0}}; 
end

adder_var_seq #(
  .DATA_WIDTH (C_DATA_WIDTH)
) adder (
  .clk      (aclk   ),
  .rst_n    (areset ),
  .i_data   (s_tdata),
  .i_valid  (s_tvalid & s_tready_inner),
  .o_data   (m_tdata_inner),
  .o_valid  (m_tvalid_inner),
  .i_en     (1'b1)
);

always @(*) begin
  if (!areset) begin
    m_tdata_buffer = {C_DATA_WIDTH{1'b0}};
    m_tvalid_buffer = 1'b0;
  end
  else if (m_tvalid_inner) begin
    m_tdata_buffer = m_tdata_inner;
    m_tvalid_buffer = m_tvalid_inner;
  end
  else if (m_tready & m_tvalid_buffer & cnt == 1'b0) begin
    m_tdata_buffer = {C_DATA_WIDTH{1'b0}};
    m_tvalid_buffer = 1'b0;
  end
  else begin
    m_tdata_buffer = m_tdata_buffer;
    m_tvalid_buffer = m_tvalid_buffer;
  end
end

assign  m_tdata = m_tdata_buffer[C_DATA_WIDTH-1:0];
assign m_tvalid = m_tvalid_buffer;
assign s_tready = s_tready_inner;

/* 
/////////////////////////////////////////////////////////////////////////////
// Variables
/////////////////////////////////////////////////////////////////////////////
logic [C_DATA_WIDTH-1:0] acc;

/////////////////////////////////////////////////////////////////////////////
// Logic
/////////////////////////////////////////////////////////////////////////////

always_comb begin 
  acc = s_tdata[0]; 
  for (int i = 1; i < C_NUM_CHANNELS; i++) begin 
    acc = acc + s_tdata[i]; 
  end
end

assign m_tvalid = &s_tvalid;
assign m_tdata = acc;

// Only assert s_tready when transfer has been accepted.  tready asserted on all channels simultaneously
assign s_tready = m_tready & m_tvalid ? {C_NUM_CHANNELS{1'b1}} : {C_NUM_CHANNELS{1'b0}};

 */
endmodule : krnl_vadd_rtl_adder

`default_nettype wire
