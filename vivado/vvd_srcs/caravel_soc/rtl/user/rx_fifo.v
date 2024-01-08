
module rx_fifo (
  input wire clk,
  input wire rst_n,
  input wire wr_en,
  input wire rd_en,
  input wire busy,
  input wire frame_error,
  input wire rx_irq,
  input wire [7:0]wr_data,
  output reg [7:0]rd_data,
  output reg full,
  output reg empty,
  output reg irq,
  output reg finish //rx_fifo--->rx
);
  
  reg [1:0]stat_reg;
  reg [7:0]mem[0:4]; //用於儲存資料  
  reg [2:0]wr_ptr,rd_ptr,count; //count 
  reg flag; //用來判斷是否成功寫入，若成功寫入則 flag=1
  reg rx_full;
  
  wire frame_err,overrun_err;
  assign frame_err = busy & frame_error;
  assign overrun_err = busy & rx_full;
  
  always@(posedge clk)begin
	if(!rst_n)begin
		stat_reg <= 2'b01;
		rx_full<=0;
	end else begin
		if(rx_irq && !stat_reg[1] && !frame_error)begin
			stat_reg <= 2'b10;
			rx_full<=1;
		end
		else if( finish || frame_error)begin
			stat_reg <= 2'b01;
			rx_full<=0;
		end
	end
  end
  
  //將暫存器中的資料清零
  always@(posedge clk)begin
    if(!rst_n)begin
      mem[0]<=8'd0;
      mem[1]<=8'd0;
      mem[2]<=8'd0;
      mem[3]<=8'd0;
      mem[4]<=8'd0;
    end //將寫入的資料寫入暫存器中
    else if(wr_en&~full&~frame_err&~overrun_err) begin
      mem[wr_ptr]<=wr_data;
	  finish <= 1;
	  flag<=1;
    end
    else begin //保存暫存器的值不變
      mem[wr_ptr]<=mem[wr_ptr];
	  flag<=0;
	  finish <= 0;
    end	
  end
  

// wr_ptr 用來指到要寫入暫存器中的哪個位置
  always@(posedge clk)begin
    if(!rst_n)begin
      wr_ptr<=3'd0;
    end
    else if(wr_en&~full&flag) begin 
      wr_ptr<=wr_ptr+3'd1;
    end
    else begin
      wr_ptr<=wr_ptr;
    end
  end
  
  //將暫存器中的值送給 rd_data
  always@(posedge clk)begin
    if(!rst_n)begin
      rd_data<=8'd0;
	  end
    else if(rd_en&~empty) begin
      rd_data<=mem[rd_ptr];
    end
    else begin
      rd_data<=rd_data;
    end
  	
  end
  
  // rd_ptr 在讀取資料始能和 fifo 內部不為空的時候會啟動
  always@(posedge clk)begin
    if(!rst_n)begin
      rd_ptr<=3'd0;
    end
    else if(rd_en&~empty) begin
      rd_ptr<=rd_ptr+3'd1;
    end
    else begin
      rd_ptr<=rd_ptr;
    end
  end
  
  //reset 的時候代表所有動作結束
  //count 在有寫始能，沒有讀取始能，和還沒滿的時候會加1 是用來計算 fifo 是否滿了沒
  //而且count 在有讀始能，沒有寫始能，和沒有空的時候會減一，是用來計算 fifo 是否為空
  //所以寫和讀的動作是分開的
  always@(posedge clk)begin
    if(!rst_n)begin
      count<=3'd0;
    end
    else if(wr_en&~rd_en&~full&flag) begin
      count<=count+3'd1;
    end
    else if(rd_en&~wr_en&~empty) begin
      count<=count-3'd1;
    end   
    else begin
      count<=count;
    end 
  end
  //當 count=3 的時候，代表fifo滿了
  //當 count=0 的時候，代表fifo空了

  always @* begin
  full = (count == 3'd3) ? 1'b1 : 1'b0;
  empty = (count == 3'd0) ? 1'b1 : 1'b0;
  end
 
  //irq
   always @(posedge clk) begin
    if (!rst_n) begin
      irq <= 1'b0;
    end
    else begin
      irq <= (empty);
    end
  end
  
endmodule
