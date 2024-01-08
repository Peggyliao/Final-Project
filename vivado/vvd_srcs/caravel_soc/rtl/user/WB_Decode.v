`default_nettype wire

module WB_Decode(
    // Wishbone Slave ports
    input wire wb_clk_i,
    input wire wb_rst_i,
    input wire wbs_stb_i,
    input wire wbs_cyc_i,
    input wire wbs_we_i,
    input wire [3:0] wbs_sel_i,
    input wire [31:0] wbs_dat_i,
    input wire [31:0] wbs_adr_i,
    output wire wbs_ack_o,
    output wire [31:0] wbs_dat_o,

    input wire [37:0] io_in,
    output wire [37:0] io_out,
    output wire [37:0] io_oeb,
    
    output wire [2:0] irq
);

wire uart_ack_o, exmem_ack_o;
wire [31:0] uart_dat_o, exmem_dat_o;

assign wbs_ack_o = (wbs_adr_i[31:24] == 8'h30) ? uart_ack_o : 
				   (wbs_adr_i[31:24] == 8'h38) ? exmem_ack_o : 0;
assign wbs_dat_o = (wbs_adr_i[31:24] == 8'h30) ? uart_dat_o :
				   (wbs_adr_i[31:24] == 8'h38) ? exmem_dat_o : 0;

uart uart(
    .wb_clk_i       (wb_clk_i   ),
    .wb_rst_i       (wb_rst_i   ),
    .wbs_stb_i      (wbs_stb_i ), 
	.wbs_cyc_i      (wbs_cyc_i ),
    .wbs_we_i       (wbs_we_i   ),              
    .wbs_sel_i      (wbs_sel_i  ),              
    .wbs_dat_i      (wbs_dat_i  ),              
    .wbs_adr_i      (wbs_adr_i  ),              
    .wbs_ack_o      (uart_ack_o  ),              
    .wbs_dat_o      (uart_dat_o  ),
    .io_in          (io_in      ),
    .io_out         (io_out     ),
    .io_oeb         (io_oeb     ),
    .user_irq       (irq        )
);

exmem exmem(
    .wb_clk_i       (wb_clk_i   ),
    .wb_rst_i       (wb_rst_i   ),
    .wbs_stb_i      (wbs_stb_i ), 
	.wbs_cyc_i      (wbs_cyc_i ),              
    .wbs_we_i       (wbs_we_i   ),              
    .wbs_sel_i      (wbs_sel_i  ),              
    .wbs_dat_i      (wbs_dat_i  ),              
    .wbs_adr_i      (wbs_adr_i  ),              
    .wbs_ack_o      (exmem_ack_o ),              
    .wbs_dat_o      (exmem_dat_o )                 
);
endmodule

`default_nettype wire