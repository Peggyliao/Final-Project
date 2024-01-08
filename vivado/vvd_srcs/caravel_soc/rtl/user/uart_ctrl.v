module ctrl(
    input wire        rst_n,
    input wire        clk,
    input wire        i_wb_valid,
    input wire [31:0] i_wb_adr,
    input wire        i_wb_we,
    input wire [31:0] i_wb_dat,
    input wire [3:0]  i_wb_sel,
    output reg        o_wb_ack,
	output reg [31:0] o_wb_dat,
	
    input wire [7:0]  i_rx,
    output reg [7:0]  o_tx,
    input wire        i_tx_start_clear,	
	
    output reg        tx_fifo_wr_en, //tx_fifo_wr_en
	output reg        tx_fifo_rd_en,
	output reg        rx_fifo_wr_en,
	output reg        rx_fifo_rd_en,
	
	input wire        tx_fifo_full,
	input wire        rx_fifo_full,
	input wire        tx_fifo_empty,
	input wire        rx_fifo_empty
);

// Declare the UART memory mapped registers address
localparam RX_DATA  = 32'h3000_0000;

localparam TX_DATA	= 32'h3000_0004;

localparam STAT_REG = 32'h3000_0008;

//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|RX_DATA |  RESERVERD  |                        DATA BITS                              |
//|        |    31-8     |  7    |  6    |  5    |  4    |  3    |  2    |  1    |  0    |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|TX_DATA |  RESERVERD  |                        DATA BITS                              |
//|        |    31-8     |  7    |  6    |  5    |  4    |  3    |  2    |  1    |  0    |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
//|STAT_REG|  RESERVERD  | tx_fifo_full  | tx_fifo_empty | rx_fifo_full  | rx_fifo_empty |  Frame Err  |  Overrun Err  |  Tx_full  |  Tx_empty  |  Rx_full  |  Rx_empty |
//|        |    31-6     | 9             | 8             | 7             | 6             |  5          |  4            |  3        |  2         |  1        |  0        |
//+------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+

reg [31:0] rx_buffer;
reg [31:0] tx_buffer;
reg [31:0] stat_reg;    
reg tx_start_local;
//reg start;

always@(posedge clk or negedge rst_n)begin
    //對 rst_n 的重置處理 當 rst_n 為低電平時，將 stat_reg 初始化為 32'h0000_0005
    if(!rst_n)begin
        stat_reg <= 32'h0000_0140;
    end else begin
	    // 這裡是其他的狀態更新邏輯
        /*if(i_wb_valid && !i_wb_we)begin
            if(i_wb_adr==STAT_REG)
                stat_reg[5:4] <= 2'b00; //(Frame Err, Overrun Err )
        end*/
        //狀態寄存器更新（Status Register Updates）程式碼中，根據傳送器忙碌、幀錯誤等條件，更新 stat_reg 寄存器。
        /*if(i_tx_busy)
            stat_reg[3:2] <= 2'b10;// (Tx_full, Tx_empty)
        else
            stat_reg[3:2] <= 2'b01;
			
		if(i_frame_err && i_rx_busy)
            stat_reg[5] <= 1'b1;  //(Frame Err)
        else if(i_irq && !stat_reg[1] && !i_frame_err) //(Rx_full)
            stat_reg[1:0] <= 2'b10; //(Rx_full, Rx_empty)
        else if(i_rx_busy && stat_reg[1:0]==2'b10) //(Rx_full, Rx_empty)
            stat_reg[4] <= 1'b1; //(Overrun Err)
        else if((i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we && stat_reg[1:0]==2'b10) || i_frame_err)
            stat_reg[1:0] <= 2'b01;//(Rx_full, Rx_empty)
		*/
			
		if(rx_fifo_empty)
		    stat_reg[6] <=1'b1;
		else 
		    stat_reg[6] <=1'b0;
		if(rx_fifo_full)
		    stat_reg[7] <=1'b1;
		else
		    stat_reg[7] <=1'b0;
			
		if(tx_fifo_empty)
		    stat_reg[8] <=1'b1;
		else 
		    stat_reg[8] <=1'b0;
			
		if(tx_fifo_full)
		    stat_reg[9] <=1'b1;
		else 
		    stat_reg[9] <=1'b0;
    end
end


//tx buffer
always@(posedge clk or negedge rst_n)begin
    //對 i_tx_start_clear 的重置處理 當 rst_n 為低電平或者 i_tx_start_clear 信號為高電平時，將 tx_buffer 初始化為 32'h00000000 並且 tx_start_local 初始化為 1'b0
    if(!rst_n || i_tx_start_clear)begin //*tx empty
        tx_buffer <= 32'h00000000;
        tx_start_local <= 1'b0;
    end else begin
	    // tx buffer 傳輸緩衝區更新（Transmit Buffer Updates) 根據 Wishbone 寫入，更新 tx_buffer 緩衝區
        if(i_wb_valid && i_wb_we && i_wb_adr==TX_DATA)begin //*|start |rd_en
            tx_buffer <= i_wb_dat;
            tx_start_local <= 1'b1;
        end
    end
end

//////////////////////////////////////////////////////////// 
//rx buffer
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        rx_buffer <= 32'h00000000;
    end else begin
	    //rx buffer 接收緩衝區更新（Receive Buffer Updates） 程式碼中，當中斷發生並滿足條件時，更新 rx_buffer 緩衝區。
        if(stat_reg[7]==1'b0)begin 
            rx_buffer <= i_rx;
            //$display("rx_buffer: %d", i_rx);
        end
    end
end

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_wb_dat <= 32'h00000000;
    end else begin
	    //Wishbone讀取處理（Wishbone Read Handling） 程式碼中，根據 Wishbone 讀取的地址提供相應的數據。
        if(i_wb_valid && !i_wb_we)begin
            case(i_wb_adr)
                RX_DATA:begin
                    o_wb_dat <= rx_buffer;
                end
                STAT_REG:begin
                    o_wb_dat <= stat_reg;
                end
                default:begin 
                    o_wb_dat <= 32'h00000000;
                end
            endcase
        end
    end
end

//rx fifo enable
always@(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_fifo_rd_en <= 1'b0;  
		rx_fifo_wr_en <= 1'b0;
    end else begin
		//rx_fifo_rd_en
        if (i_wb_valid && i_wb_adr==RX_DATA && !i_wb_we && stat_reg[6]==1'b0) begin 
            rx_fifo_rd_en <= 1'b1;  
        end else begin
            rx_fifo_rd_en <= 1'b0;
        end
		if (stat_reg[7]==1'b0) begin // rx_fifo_wr_en
			rx_fifo_wr_en <= 1'b1;
		end else begin
			rx_fifo_wr_en <= 1'b0;  // 在其他情况下清除 rx_fifo_wr_en
		end
    end
end

//tx fifo enable
always@(posedge clk or negedge rst_n) begin
    if (!rst_n || i_tx_start_clear) begin
        o_tx <= 8'b0;
        tx_fifo_wr_en <= 1'b0;
        tx_fifo_rd_en <= 1'b0; 
    end else begin
        if (stat_reg[9]==1'b0) begin // tx_fifo_wr_en
            o_tx <= tx_buffer[7:0];
            tx_fifo_wr_en <= tx_start_local;
        end else begin
            tx_fifo_wr_en <= 1'b0;
        end
		
		if (stat_reg[8]==1'b0) begin // tx_fifo_rd_en
			tx_fifo_rd_en <= 1'b1;
		end else begin
			tx_fifo_rd_en <= 1'b0;
        end
    end
end

///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////  Wishbone 存取的確認機制 o_wb_ack 被設置為高電位，表示確認存取操作
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        o_wb_ack <= 1'b0;
    end else begin
	    // Wishbone確認（Wishbone Acknowledge） 根據 Wishbone 寫入的有效性設置 Wishbone 確認信號
        if(i_wb_valid)  
            o_wb_ack <= 1'b1;
        else            
            o_wb_ack <= 1'b0;
    end
end

endmodule
