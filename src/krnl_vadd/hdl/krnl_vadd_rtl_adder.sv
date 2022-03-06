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

logic [C_DATA_WIDTH-1:0] m_tdata_inner;
logic m_tvalid_inner;
logic [C_NUM_CHANNELS-1:0] i_valid_inner;

adder_var_seq #(
  .DATA_WIDTH (C_DATA_WIDTH)
) adder (
  .clk      (aclk   ),
  .rst_n    (areset ),
  .i_data   (s_tdata),
  .i_valid  (i_valid_inner),
  .o_data   (m_tdata_inner),
  .o_valid  (m_tvalid_inner),
  .i_en     (1'b1)
);


//assign i_valid_inner = s_tvalid & s_tready;
assign i_valid_inner = s_tvalid;
assign m_tdata = m_tdata_inner;
assign m_tvalid = m_tvalid_inner;

//assign s_tready = m_tready ? {C_NUM_CHANNELS{1'b1}} : {C_NUM_CHANNELS{1'b0}};
assign s_tready = m_tready & m_tvalid_inner ? {C_NUM_CHANNELS{1'b1}} : {C_NUM_CHANNELS{1'b0}};



endmodule : krnl_vadd_rtl_adder

`default_nettype wire
