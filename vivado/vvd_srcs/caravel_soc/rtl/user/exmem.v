`default_nettype wire

module exmem #(
    parameter BITS = 32,
    parameter DELAYS = 10
)(
    // Wishbone Slave ports (WB MI A)
    input wire wb_clk_i,
    input wire wb_rst_i,
	input wire wbs_stb_i,
	input wire wbs_cyc_i,
    input wire wbs_we_i,
    input wire [3:0] wbs_sel_i,
    input wire [31:0] wbs_dat_i,
    input wire [31:0] wbs_adr_i,
    output wire wbs_ack_o,
    output reg [31:0] wbs_dat_o
);

wire bram_decoded;
wire [3:0] bram_we;
wire bram_en;
wire [BITS-1:0] bram_di;
wire [BITS-1:0] bram_do; 
wire [11:0] bram_adr;

reg ready;
reg [3:0] delay_cnt;

// WB MI A
assign bram_decoded = (wbs_adr_i[31:24] == 8'h38) ? 1'b1 : 1'b0;
assign bram_en = wbs_stb_i & wbs_cyc_i & bram_decoded;
assign bram_we = wbs_sel_i & {4{wbs_we_i}};
assign bram_di = wbs_dat_i;
assign bram_adr = (wbs_adr_i - 32'h38000000) >> 2;
assign wbs_ack_o = ready;

always@(posedge wb_clk_i or posedge wb_rst_i)begin
    if(wb_rst_i)begin
        delay_cnt <= 0;
        ready <= 0;
        wbs_dat_o <= 0;
    end else begin
        if(delay_cnt == DELAYS)begin
			delay_cnt <= 0;
			ready <= 1;
			wbs_dat_o <= bram_do;
		end else begin
			delay_cnt <= (bram_en && ~ready)? delay_cnt + 1 : delay_cnt;
			ready <= 0;
			wbs_dat_o <= 0;
		end
    end
end

bram user_bram (
    .CLK(wb_clk_i),
    .WE0(bram_we),
    .EN0(bram_en),
    .Di0(bram_di),
    .Do0(bram_do),
    .A0({20'b0, bram_adr})
);

endmodule

`default_nettype wire
