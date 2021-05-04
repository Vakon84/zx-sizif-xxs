`include "util.vh"
import common::*;
module screen(
	input rst_n,
	input clk28,

	cpu_bus bus,
	output [14:0] screen_addr,
	output [5:0] up_addr,

	input clkwait,
	input timings_t timings,
	input [2:0] border,
	input up_en,

	output reg [1:0] r,
	output reg [1:0] g,
	output reg [1:0] b,
	output reg vsync,
	output reg hsync,
	output reg csync,

	output read,
	output read_up,
	output blink,
	output load,
	output reg [7:0] attr_next,

	output [8:0] hc_out,
	output [8:0] vc_out,
	output clk14,
	output clk7,
	output clk35,
	output ck14,
	output ck7,
	output ck35
);


localparam H_AREA         = 256;
localparam V_AREA         = 192;
localparam SCREEN_DELAY   = 8;

localparam H_LBORDER_S48  = 48 - SCREEN_DELAY;
localparam H_RBORDER_S48  = 48 + SCREEN_DELAY;
localparam H_BLANK1_S48   = 17;
localparam H_SYNC_S48     = 33;
localparam H_BLANK2_S48   = 46;
localparam H_TOTAL_S48    = H_AREA + H_RBORDER_S48 + H_BLANK1_S48 + H_SYNC_S48 + H_BLANK2_S48 + H_LBORDER_S48;
localparam V_BBORDER_S48  = 56;
localparam V_SYNC_S48     = 8;
localparam V_TBORDER_S48  = 56;
localparam V_TOTAL_S48    = V_AREA + V_BBORDER_S48 + V_SYNC_S48 + V_TBORDER_S48;

localparam H_LBORDER_S128 = 48 - SCREEN_DELAY;
localparam H_RBORDER_S128 = 48 + SCREEN_DELAY;
localparam H_BLANK1_S128  = 25;
localparam H_SYNC_S128    = 33;
localparam H_BLANK2_S128  = 46;
localparam H_TOTAL_S128   = H_AREA + H_RBORDER_S128 + H_BLANK1_S128 + H_SYNC_S128 + H_BLANK2_S128 + H_LBORDER_S128;
localparam V_BBORDER_S128 = 55;
localparam V_SYNC_S128    = 8;
localparam V_TBORDER_S128 = 56;
localparam V_TOTAL_S128   = V_AREA + V_BBORDER_S128 + V_SYNC_S128 + V_TBORDER_S128;

localparam H_LBORDER_PENT = 54 - SCREEN_DELAY;
localparam H_RBORDER_PENT = 53 + SCREEN_DELAY;
localparam H_BLANK1_PENT  = 12;
localparam H_SYNC_PENT    = 33;
localparam H_BLANK2_PENT  = 40;
localparam H_TOTAL_PENT   = H_AREA + H_RBORDER_PENT + H_BLANK1_PENT + H_SYNC_PENT + H_BLANK2_PENT + H_LBORDER_PENT;
localparam V_BBORDER_PENT = 56;
localparam V_SYNC_PENT    = 8;
localparam V_TBORDER_PENT = 64;
localparam V_TOTAL_PENT   = V_AREA + V_BBORDER_PENT + V_SYNC_PENT + V_TBORDER_PENT;

reg [`CLOG2(`MAX(V_TOTAL_S128, V_TOTAL_PENT))-1:0] vc;
reg [`CLOG2(`MAX(H_TOTAL_S128, H_TOTAL_PENT))+1:0] hc0;
wire [`CLOG2(`MAX(H_TOTAL_S128, H_TOTAL_PENT))-1:0] hc = hc0[$bits(hc0)-1:2];

assign vc_out = vc;
assign hc_out = hc;
assign clk14 = hc0[0];
assign clk7 = hc0[1];
assign clk35 = hc0[2];
assign ck14 = hc0[0];
assign ck7 = hc0[0] & hc0[1];
assign ck35 = hc0[0] & hc0[1] & hc0[2];

wire hc0_reset =
	(timings == TIMINGS_PENT)?
		hc0 == (H_TOTAL_PENT<<2) - 1'b1 :
	(timings == TIMINGS_S128)?
		hc0 == (H_TOTAL_S128<<2) - 1'b1 :
	// 48K
		hc0 == (H_TOTAL_S48<<2) - 1'b1 ;
wire vc_reset = 
	(timings == TIMINGS_PENT)?
		vc == V_TOTAL_PENT - 1'b1 :
	(timings == TIMINGS_S128)?
		vc == V_TOTAL_S128 - 1'b1 :
	// 48K
		vc == V_TOTAL_S48 - 1'b1;
wire hsync0 =
	(timings == TIMINGS_PENT)?
		(hc >= (H_AREA + H_RBORDER_PENT + H_BLANK1_PENT)) &&
			(hc <  (H_AREA + H_RBORDER_PENT + H_BLANK1_PENT + H_SYNC_PENT)) :
	(timings == TIMINGS_S128)?
		(hc >= (H_AREA + H_RBORDER_S128 + H_BLANK1_S128)) &&
			(hc <  (H_AREA + H_RBORDER_S128 + H_BLANK1_S128 + H_SYNC_S128)) :
	// 48K
		(hc >= (H_AREA + H_RBORDER_S48 + H_BLANK1_S48)) &&
			(hc <  (H_AREA + H_RBORDER_S48 + H_BLANK1_S48 + H_SYNC_S48)) ;
wire vsync0 = 
	(timings == TIMINGS_PENT)?
		(vc >= (V_AREA + V_BBORDER_PENT)) && (vc < (V_AREA + V_BBORDER_PENT + V_SYNC_PENT)) :
	(timings == TIMINGS_S128)?
		(vc >= (V_AREA + V_BBORDER_S128)) && (vc < (V_AREA + V_BBORDER_S128 + V_SYNC_S128)) :
	// 48K
		(vc >= (V_AREA + V_BBORDER_S48)) && (vc < (V_AREA + V_BBORDER_S48 + V_SYNC_S48)) ;
wire blank =
	(timings == TIMINGS_PENT)?
		((vc >= (V_AREA + V_BBORDER_PENT)) && (vc < (V_AREA + V_BBORDER_PENT + V_SYNC_PENT))) ||
			((hc >= (H_AREA + H_RBORDER_PENT)) &&
			 (hc <  (H_AREA + H_RBORDER_PENT + H_BLANK1_PENT + H_SYNC_PENT + H_BLANK2_PENT))) :
	(timings == TIMINGS_S128)?
		((vc >= (V_AREA + V_BBORDER_S128)) && (vc < (V_AREA + V_BBORDER_S128 + V_SYNC_S128))) ||
			((hc >= (H_AREA + H_RBORDER_S128)) &&
			 (hc <  (H_AREA + H_RBORDER_S128 + H_BLANK1_S128 + H_SYNC_S128 + H_BLANK2_S128))) :
	// 48K
		((vc >= (V_AREA + V_BBORDER_S48)) && (vc < (V_AREA + V_BBORDER_S48 + V_SYNC_S48))) ||
			((hc >= (H_AREA + H_RBORDER_S48)) &&
			 (hc <  (H_AREA + H_RBORDER_S48 + H_BLANK1_S48 + H_SYNC_S48 + H_BLANK2_S48))) ;

always @(posedge clk28 or negedge rst_n) begin
	if (!rst_n) begin
		hc0 <= 0;
		vc <= 0;
	end
	else if (hc0_reset) begin
		hc0 <= 0;
		if (vc_reset) begin
			vc <= 0;
		end
		else begin
			vc <= vc + 1'b1;
		end
	end
	else begin
		hc0 <= hc0 + 1'b1;
	end
end

reg [4:0] blink_cnt;
assign blink = blink_cnt[$bits(blink_cnt)-1];
always @(posedge clk28 or negedge rst_n) begin
	if (!rst_n)
		blink_cnt <= 0;
	else if (hc0_reset && vc_reset)
		blink_cnt <= blink_cnt + 1'b1;
end

wire [7:0] attr_border = {2'b00, border, 3'b000};

reg [7:0] bitmap, attr, bitmap_next;
reg [7:0] up_ink, up_paper, up_ink_next, up_paper_next;
wire pixel = bitmap[7];
reg screen_read;
assign read = screen_read;
reg [1:0] screen_read_step;
wire screen_read_step_reset = hc0[4:0] == 5'b11111 || hc0_reset;
wire bitmap_read = screen_read && screen_read_step == 2'd0;
wire attr_read = screen_read && screen_read_step == 2'd1;
wire up_ink_read = screen_read && screen_read_step == 2'd2;
wire up_paper_read = screen_read && screen_read_step == 2'd3;
assign read_up = up_ink_read || up_paper_read;
assign screen_addr =  bitmap_read? 
							{ 2'b10, vc[7:6], vc[2:0], vc[5:3], hc[7:3] } :
							{ 5'b10110, vc[7:3], hc[7:3] };
assign up_addr = up_ink_read?
							{ attr_next[7:6], 1'b0, attr_next[2:0] } :
							{ attr_next[7:6], 1'b1, attr_next[5:3] };
wire screen_load = (vc < V_AREA) && (hc < H_AREA || hc0_reset);
assign load = screen_load;
wire screen_show = (vc < V_AREA) && (hc0 >= (SCREEN_DELAY<<2) - 2) && (hc0 < ((H_AREA + SCREEN_DELAY)<<2) - 2);
wire screen_update = vc < V_AREA && hc <= H_AREA && hc != 0 && hc0[4:0] == 5'b11110;
wire border_update = !screen_show && ((timings == TIMINGS_PENT && ck7) || hc0[4:0] == 5'b11110);
wire bitmap_shift = hc0[1:0] == 2'b10;
wire screen_read_next = (screen_load || up_en) && ((!bus.iorq && !bus.mreq) || bus.rfsh || clkwait);

always @(posedge clk28 or negedge rst_n) begin
	if (!rst_n) begin
		screen_read <= 0;
		screen_read_step <= 0;
		attr <= 0;
		bitmap <= 0;
		attr_next <= 0;
		bitmap_next <= 0;
		up_ink <= 0;
		up_paper <= 0;
		up_ink_next <= 0;
		up_paper_next <= 0;
	end
	else begin
		if (ck14) begin
			screen_read <= screen_read_next;
			if (screen_read && screen_read_step[0] && !up_en)
				screen_read_step <= 0;
			else if (!screen_load && up_en)
				screen_read_step <= 2'd3;
			else if (screen_read_step_reset)
				screen_read_step <= 0;
			else if (screen_read)
				screen_read_step <= screen_read_step + 1'b1;

			if (attr_read)
				attr_next <= bus.d;
			else if (!screen_load)
				attr_next <= attr_border;
			if (bitmap_read)
				bitmap_next <= bus.d;
			if (up_ink_read)
				up_ink_next <= bus.d;
			if (up_paper_read)
				up_paper_next <= bus.d;
		end

		if (border_update)
			attr <= attr_border;
		else if (screen_update)
			attr <= attr_next;

		if (screen_update)
			bitmap <= bitmap_next;
		else if (bitmap_shift)
			bitmap <= {bitmap[6:0], 1'b0};

		if (screen_update)
			up_ink <= up_ink_next;
		if (screen_update || (!screen_show && !screen_load))
			up_paper <= up_paper_next;
	end
end


always @(posedge clk28) begin
	if (blank)
		{g, r, b} = 6'b000000;
	else if (up_en) begin
		g = pixel? up_ink[7:5] : up_paper[7:5];
		r = pixel? up_ink[4:2] : up_paper[4:2];
		b = pixel? up_ink[1:0] : up_paper[1:0];
	end
	else begin
		{g[1], r[1], b[1]} = (pixel ^ (attr[7] & blink))? attr[2:0] : attr[5:3];
		{g[0], r[0], b[0]} = ((g[1] | r[1] | b[1]) & attr[6])? 3'b111 : 3'b000;
	end
	csync = ~(vsync0 ^ hsync0);
	vsync = ~vsync0;
	hsync = ~hsync0;
end

endmodule