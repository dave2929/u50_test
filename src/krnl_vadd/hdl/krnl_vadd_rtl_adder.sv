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

localparam NUM_DATA_IN_BUF = 32;
localparam CNT_VALID_WIDTH =  1 + $clog2(NUM_DATA_IN_BUF);
localparam CUT_OFF_THRESHOLD = 1;

logic [C_DATA_WIDTH-1:0] m_tdata_inner;
logic m_tvalid_inner;
logic cnt; // number of data in buffer
logic s_tready_inner;

always @(posedge aclk) begin
  if (areset)
    cnt <= 'b0;
  else if (s_tready & m_tvalid_inner & m_tready)
    cnt <= cnt;
  else if (s_tready & (~(m_tvalid_inner & m_tready)))
    cnt <= cnt + {{(CNT_VALID_WIDTH-1){1'b0}},{1'b1}};  
  else if (~s_tready & m_tvalid_inner & m_tready)
    cnt <= cnt - {{(CNT_VALID_WIDTH-1){1'b0}},{1'b1}};  
  else
    cnt <= cnt;
end

always @(*) begin
  if (areset)
    s_tready_inner <= {C_NUM_CHANNELS{1'b0}};
  else if ((cnt >= CUT_OFF_THRESHOLD) & m_tready & m_tvalid_inner & (&s_tvalid))
    s_tready_inner <= {C_NUM_CHANNELS{1'b1}};
  else if ((cnt >= CUT_OFF_THRESHOLD) & (~(m_tready & m_tvalid_inner)) & (&s_tvalid))
    s_tready_inner <= {C_NUM_CHANNELS{1'b0}}; 
  else if ((cnt < CUT_OFF_THRESHOLD) & (&s_tvalid))
    s_tready_inner <= {C_NUM_CHANNELS{1'b1}};
  else
    s_tready_inner <= {C_NUM_CHANNELS{1'b0}}; 
end

//systolic_array_top_axi_seq reference
// tlast->delete, strb -> 1

adder_var_seq #(
  .DATA_WIDTH (C_DATA_WIDTH)
) adder (
  .clk      (aclk   ),
  .rst_n    (areset ),
  .i_data   (s_tdata),
  .i_valid  (s_tvalid),
  .o_data   (m_tdata_inner),
  .o_valid  (m_tvalid_inner),
  .i_en     (1'b1)
);


assign m_tdata = m_tdata_inner;
assign m_tvalid = m_tvalid_inner;
assign s_tready = s_tready_inner;


endmodule : krnl_vadd_rtl_adder

`default_nettype wire
