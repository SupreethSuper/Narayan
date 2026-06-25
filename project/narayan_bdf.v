// Copyright (C) 2025  Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions 
// and other software and tools, and any partner logic 
// functions, and any output files from any of the foregoing 
// (including device programming or simulation files), and any 
// associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License 
// Subscription Agreement, the Altera Quartus Prime License Agreement,
// the Altera IP License Agreement, or other applicable license
// agreement, including, without limitation, that your use is for
// the sole purpose of programming logic devices manufactured by
// Altera and sold by Altera or its authorized distributors.  Please
// refer to the Altera Software License Subscription Agreements 
// on the Quartus Prime software download page.

// PROGRAM		"Quartus Prime"
// VERSION		"Version 25.1std.0 Build 1129 10/21/2025 SC Lite Edition"
// CREATED		"Fri Jun 19 12:53:14 2026"

module narayan_bdf(
	clk,
	rw_,
	rst,
	cs,
	next,
	data_in,
	mem1_out,
	mem2_out,
	mem3_out,
	mem4_out
);


input wire	clk;
input wire	rw_;
input wire	rst;
input wire	cs;
input wire	next;
input wire	[31:0] data_in;
output wire	[31:0] mem1_out;
output wire	[31:0] mem2_out;
output wire	[31:0] mem3_out;
output wire	[31:0] mem4_out;

wire	[3:0] cs_out;
wire	SYNTHESIZED_WIRE_20;
wire	SYNTHESIZED_WIRE_21;
wire	SYNTHESIZED_WIRE_22;
wire	[31:0] SYNTHESIZED_WIRE_23;
wire	[4:0] SYNTHESIZED_WIRE_24;





scratchpad_memory	b2v_inst(
	.clk(SYNTHESIZED_WIRE_20),
	.rw_(SYNTHESIZED_WIRE_21),
	.cs(cs_out[0]),
	.rst(SYNTHESIZED_WIRE_22),
	.data_in(SYNTHESIZED_WIRE_23),
	.wr_addr(SYNTHESIZED_WIRE_24),
	.data_out(mem1_out));
	defparam	b2v_inst.COLS = 5;
	defparam	b2v_inst.DATA_WIDTH = 32;
	defparam	b2v_inst.MEM_ADDRESS = 5;
	defparam	b2v_inst.ROWS = 5;


scratchpad_memory	b2v_inst1(
	.clk(SYNTHESIZED_WIRE_20),
	.rw_(SYNTHESIZED_WIRE_21),
	.cs(cs_out[1]),
	.rst(SYNTHESIZED_WIRE_22),
	.data_in(SYNTHESIZED_WIRE_23),
	.wr_addr(SYNTHESIZED_WIRE_24),
	.data_out(mem2_out));
	defparam	b2v_inst1.COLS = 5;
	defparam	b2v_inst1.DATA_WIDTH = 32;
	defparam	b2v_inst1.MEM_ADDRESS = 5;
	defparam	b2v_inst1.ROWS = 5;


scratchpad_memory	b2v_inst2(
	.clk(SYNTHESIZED_WIRE_20),
	.rw_(SYNTHESIZED_WIRE_21),
	.cs(cs_out[2]),
	.rst(SYNTHESIZED_WIRE_22),
	.data_in(SYNTHESIZED_WIRE_23),
	.wr_addr(SYNTHESIZED_WIRE_24),
	.data_out(mem3_out));
	defparam	b2v_inst2.COLS = 5;
	defparam	b2v_inst2.DATA_WIDTH = 32;
	defparam	b2v_inst2.MEM_ADDRESS = 5;
	defparam	b2v_inst2.ROWS = 5;


scratchpad_memory	b2v_inst3(
	.clk(SYNTHESIZED_WIRE_20),
	.rw_(SYNTHESIZED_WIRE_21),
	.cs(cs_out[3]),
	.rst(SYNTHESIZED_WIRE_22),
	.data_in(SYNTHESIZED_WIRE_23),
	.wr_addr(SYNTHESIZED_WIRE_24),
	.data_out(mem4_out));
	defparam	b2v_inst3.COLS = 5;
	defparam	b2v_inst3.DATA_WIDTH = 32;
	defparam	b2v_inst3.MEM_ADDRESS = 5;
	defparam	b2v_inst3.ROWS = 5;


scheduler	b2v_inst4(
	.clk(clk),
	.rw_(rw_),
	.cs(cs),
	.rst(rst),
	.next(next),
	.data_in(data_in),
	.rw_out(SYNTHESIZED_WIRE_21),
	.rst_out(SYNTHESIZED_WIRE_22),
	.clk_out(SYNTHESIZED_WIRE_20),
	.cs_out(cs_out),
	.data_out(SYNTHESIZED_WIRE_23),
	.rd_addr(SYNTHESIZED_WIRE_24));
	defparam	b2v_inst4.COLS = 5;
	defparam	b2v_inst4.DATA_WIDTH = 32;
	defparam	b2v_inst4.GLOBAL_ADDR = 7;
	defparam	b2v_inst4.LOCAL_ADDR = 5;
	defparam	b2v_inst4.NUM_UNITS = 4;
	defparam	b2v_inst4.ROWS = 5;


endmodule
