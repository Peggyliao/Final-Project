module uart #(
  parameter BAUD_RATE = 9600 
)(
/*`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif*/
  // Wishbone Slave ports (WB MI A)
  input wire    wb_clk_i,		  // Wishbone總線的時鐘信號
  input wire    wb_rst_i,		  // Wishbone總線的重置信號
  input wire    wbs_stb_i,		  // Wishbone Slave 端的 strobe 信號， wishbone 事物開始的標誌
  input wire    wbs_cyc_i,		  // Wishbone Slave 端的 cycle 信號
  //input wire	wb_valid,
  input wire    wbs_we_i,		  // Wishbone Slave 端的 write enable 信號
  input wire    [3:0] wbs_sel_i,  // Wishbone Slave 端的 byte select 信號
  input wire    [31:0] wbs_dat_i, // Wishbone Slave 端的 data input 信號
  input wire    [31:0] wbs_adr_i, // Wishbone Slave 端的 address input 信號
  output wire   wbs_ack_o,		  // Wishbone Slave 端的 acknowledge output 信號，表示 slave 端對於 Master 端的事物有成功的處理
  output wire   [31:0] wbs_dat_o, // Wishbone Slave 端的 data output 信號 

  // IO ports
  input  [`MPRJ_IO_PADS-1:0] io_in, // The io_in[..] signals are from the pad to the user project and are always
									// active unless the pad has been configured with the "input disable" bit set.
  output [`MPRJ_IO_PADS-1:0] io_out,// The io_out[..] signals are from the user project to the pad.
  output [`MPRJ_IO_PADS-1:0] io_oeb,// The io_oeb[..] signals are from the user project to the pad cell.  This
									// controls the direction of the pad when in bidirectional mode.  When set to
									// value zero, the pad direction is output and the value of io_out[..] appears
									// on the pad.  When set to value one, the pad direction is input and the pad
									// output buffer is disabled.

  // irq
  output [2:0] user_irq
);

  // UART 
  wire  tx;
  wire  rx;

  assign io_oeb[6] = 1'b0; // Set mprj_io_31 to output
  assign io_oeb[5] = 1'b1; // Set mprj_io_30 to input
  assign io_out[6] = tx;	// Connect mprj_io_6 to tx
  assign rx = io_in[5];	// Connect mprj_io_5 to rx
  

  // FIFO
  
  wire [7:0]tx_rdata,rx_rdata;
  wire tx_fifo_full,tx_fifo_empty,rx_fifo_full,rx_fifo_empty;
  wire start,finish;
  
  wire tx_fifo_wr_en,tx_fifo_rd_en;
  wire rx_fifo_wr_en,rx_fifo_rd_en;

  
  // irq
  wire irq;
  assign user_irq = {2'b00,irq};	// Use USER_IRQ_0

  // CSR(Control and Status Registers)
  wire [7:0] rx_data; 
  wire rx_busy;
  wire [7:0] tx_data;
  wire tx_start_clear;
  wire tx_busy;
  wire frame_err;
  wire o_rx_finish;
  wire tx_clear;
  wire rx_irq;

  wire [31:0] clk_div;
  assign clk_div = 40000000 / BAUD_RATE;
  
  wire wb_valid;
  assign wb_valid = wbs_stb_i & wbs_cyc_i;
  

  // uart_ctrl
  ctrl ctrl(
	.rst_n			 (~wb_rst_i),
	.clk		 	 (wb_clk_i),
	.i_wb_valid		 (wb_valid),
	.i_wb_adr		 (wbs_adr_i),
	.i_wb_we		 (wbs_we_i),
	.i_wb_dat		 (wbs_dat_i),
	.i_wb_sel		 (wbs_sel_i),
	.o_wb_ack		 (wbs_ack_o),
	.o_wb_dat 		 (wbs_dat_o),
	
	.i_rx			 (rx_rdata),
	.o_tx		     (tx_data),
	.i_tx_start_clear(tx_clear), 
	
	.tx_fifo_wr_en	 (tx_fifo_wr_en),
	.tx_fifo_rd_en	 (tx_fifo_rd_en),
	.rx_fifo_wr_en	 (rx_fifo_wr_en),
	.rx_fifo_rd_en	 (rx_fifo_rd_en),
	
	.tx_fifo_full	 (tx_fifo_full),
	.rx_fifo_full	 (rx_fifo_full),
	.tx_fifo_empty	 (tx_fifo_empty),
	.rx_fifo_empty	 (rx_fifo_empty)

  );
  

	 // uart_tx
  uart_transmission transmission(
    .rst_n      (~wb_rst_i  ),
    .clk        (wb_clk_i   ),
    .clk_div    (clk_div    ),
    .tx         (tx         ),
    .tx_data    (tx_rdata[7:0]    ),
    .tx_start   (~tx_fifo_empty   ), //from tx_fifo
    .busy       (tx_busy    )
  );
	
	
	tx_fifo txfifo(
        .clk(wb_clk_i),
        .rst_n(~wb_rst_i),
        .wr_en(tx_fifo_wr_en),//from uart_ctrl
        .rd_en(tx_fifo_rd_en),
        .wr_data(tx_data), //tx_data
        .rd_data(tx_rdata),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty),
		.irq  (irq),
		.tx_clear(tx_clear)
    );
	
     // uart_rx
  uart_receive receive(
    .rst_n      (~wb_rst_i  ),
    .clk        (wb_clk_i   ),
    .clk_div    (clk_div    ),
    .rx         (rx         ),
	.rx_irq		(rx_irq		),
    .rx_data    (rx_data    ),	// 給 rx_fifo
    .rx_finish  (finish  	),		// data receive finish //from rx_fifo
    .frame_err  (frame_err  ),
    .busy       (rx_busy    ),
	.rx_fifo_full(rx_fifo_full)
  );
	// rx_fifo
    rx_fifo rxfifo(
        .clk(wb_clk_i),
        .rst_n(~wb_rst_i),
        .wr_en(rx_fifo_wr_en),  
        .rd_en(rx_fifo_rd_en),	
		.busy (rx_busy),
		.frame_error(frame_err),
		.rx_irq(rx_irq),
        .wr_data(rx_data),	//接收來自 rx 的值
        .rd_data(rx_rdata),
        .full(rx_fifo_full),
        .empty(rx_fifo_empty),
		.irq  (irq),
		.finish(finish) //給 uart_rx
    );


endmodule
