////////////////////////////////////////////////////////
// project: i2c_ctrl
// module : i2c_ip
// author : Charles
// date   : 2020/10/10
// version: 1.0
///////////////////////////////////////////////////////
module i2c_ip
#(
    parameter SYS_CLK = 50_000_000,
    parameter SCL_CLK = 400_000,
    parameter SCL_CNT = SYS_CLK/SCL_CLK,
    parameter IDLE    = 		8'b0000_0001,
    parameter WR_START =		8'b0000_0010,
    parameter WR_DEV_ADDR = 	8'b0000_0100,
    parameter WR_REG_ADDR = 	8'b0000_1000,
    parameter WR_DATA = 		8'b0001_0000,
    parameter RD_START =		8'b0010_0000,
    parameter RD_DATA = 		8'b0100_0000,
    parameter STOP = 			8'b1000_0000

)
(
    input clk,//系统时钟
    input rst_n,//复位,低有效
    //控制信号
    input wr_req,//写请求
    input rd_req,//读请求
    input [1:0]wr_addr_lenth,//写地址长度
    input [7:0]wr_data,//写数据
    //input [7:0]wr_addr,//写地址
    output[7:0]rd_data,//读数据
    output rd_done,//读完成
    output wr_done,//写完成
    //I2C信号
    output i2c_scl,//I2C 时钟
    inout  i2c_sda //I2C 数据
);

reg i2c_scl_r;//i2c时钟寄存器
reg [6:0]scl_cnt_r;
reg i2c_valid_r;//i2c操作有效信号,以显示i2c总线处于忙状态
reg [4:0]hilow_cnt_r;
reg [7:0]rd_data_r;
reg [7:0]state_r;
reg i2c_sda_r;
reg wr_flag_r;//写标志
reg rd_flag_r;//读标志
reg i2c_de_r;//I2C总线方向控制标志
reg wr_done_r;
reg rd_done_r;
reg [7:0]wr_data_r;
reg ack_r,non_ack_r;
reg wr_data_shift_r;
reg byte_done_flag_r;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        scl_cnt_r <= 0;
    end
    else if(i2c_valid_r)begin
		if (scl_cnt_r == SCL_CNT) begin
        scl_cnt_r <= 0;
		end
		else scl_cnt_r <= scl_cnt_r +1;
	 end 
	 else scl_cnt_r <=0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        i2c_scl_r <= 1;
    end
    else if(scl_cnt_r == SCL_CNT >>1)begin
        i2c_scl_r <= 0;
    end
	 else if(scl_cnt_r ==0)begin
		  i2c_scl_r <= 1;
	 end
	 else i2c_scl_r = i2c_scl_r;
end 
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i2c_valid_r <=0;
    end
    else if (wr_req | rd_req) begin
        i2c_valid_r <=1;
    end
    else if (rd_done | wr_done) begin
        i2c_valid_r <=0;
    end
end
reg scl_high_r,scl_low_r;//SCL低电平和高电平位置标志
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scl_high_r <= 0;
    end
    else if (i2c_valid_r) begin
        if (scl_cnt_r == (SCL_CNT >>2)) begin
            scl_high_r <=1;
        end
        else scl_high_r <=0;
    end     
    else scl_high_r <= 0;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        scl_low_r <= 0;
    end
    else if (i2c_valid_r) begin
        if (scl_cnt_r == ((SCL_CNT >>1 )+(SCL_CNT >>2))) begin
            scl_low_r <=1;
        end
        else scl_low_r <=0;
    end
    else scl_low_r <=0;
end
//i2c有效期间高低电平计数器

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        hilow_cnt_r <=0;
    end
	 else if ((state_r == WR_DEV_ADDR) |(state_r == WR_REG_ADDR) | (state_r == WR_DATA) 
		| (state_r == RD_DATA)) begin
				if(scl_high_r | scl_low_r)begin
                    if (hilow_cnt_r == 17) begin
                            hilow_cnt_r <= 0;
                    end
                    else begin   
                            hilow_cnt_r <= hilow_cnt_r+1;
                    end		  
		      end
            else hilow_cnt_r <= hilow_cnt_r;
       end       
	else hilow_cnt_r <=0;
end

//状态机
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
      state_r <= IDLE;  
      wr_flag_r <=0;
      rd_flag_r <=0;
		byte_done_flag_r <=0;
		wr_data_shift_r <=0;
		wr_data_r<=0;
		rd_data_r<=0;
    end
    else begin
        case(state_r)
        IDLE:begin
            wr_flag_r <=0;
            rd_flag_r <=0;
				byte_done_flag_r <=0;
				wr_data_shift_r <=0;
				wr_data_r<=0;
				rd_data_r<=0;				
            if (wr_req) begin
                state_r <= WR_START;
            end   
            else if(rd_req)begin
                state_r <= RD_START;
            end
            else state_r <= IDLE;
        end
        WR_START:begin
			if(wr_req)begin
				wr_flag_r <=1;
            if(scl_high_r)begin
                state_r <= WR_START;
            end
            else if (scl_low_r)begin
                state_r <= WR_DEV_ADDR;
					 wr_data_r <= wr_data;
            end
				else state_r <= WR_START;
			end
			else state_r <= IDLE;
        end
        WR_DEV_ADDR:begin
			if(wr_req | rd_req)begin
				if(byte_done_flag_r)begin
					if(ack_r)begin
						if(scl_low_r)begin
							byte_done_flag_r<=0;
							state_r <= WR_REG_ADDR;
							wr_data_r <= wr_data;							
						end
						else state_r <= WR_DEV_ADDR;
					end
					else state_r <= IDLE;
				end
				else begin 
					i2c_send_data;
				end
			end
			else state_r <= IDLE;
		  end
        WR_REG_ADDR:begin
			if(wr_req | rd_req)begin
		  		if(byte_done_flag_r)begin
					if(ack_r)begin
						if(wr_req & scl_low_r)begin
							state_r <= WR_DATA;
							byte_done_flag_r<=0;
							wr_data_r <= wr_data;
						end
						else if(rd_req & scl_low_r)begin
							state_r <= RD_DATA;
							byte_done_flag_r<=0;
						end
						else state_r <= WR_REG_ADDR;
					end
					else state_r <= IDLE;
				end
				else begin 
					i2c_send_data;
				end
			end
			else state_r <= IDLE;
		  end
        WR_DATA:begin
			if(wr_req)begin
				if(byte_done_flag_r)begin
					if(ack_r)begin
						if(scl_low_r)begin
							state_r <= STOP;
						end
						else state_r <= WR_DATA;
					end
					else state_r <= IDLE;
				end
				else begin
					i2c_send_data;
				end
			end
			else state_r <= IDLE;
		  end
        RD_START:begin
			if(rd_req)begin
				rd_flag_r <=1;
            if (scl_high_r) begin
                state_r <= RD_START;
            end
            else if(scl_low_r)begin
					 state_r <= WR_DEV_ADDR;
					 wr_data_r <= wr_data;
				end
				else state_r <= RD_START;
			end
			else state_r <= IDLE;
        end
        RD_DATA:begin
			if(rd_req)begin
				if(byte_done_flag_r)begin
					if(non_ack_r)begin
						if(scl_low_r)begin
							state_r <= STOP;
						end
						else state_r <= RD_DATA;
					end
					else state_r <= IDLE;
				end
				else begin
					i2c_rec_data;
				end
			end
			else state_r <= IDLE;
		  end
        STOP:begin
            state_r <= IDLE;
            wr_flag_r <=0;
            rd_flag_r <=0;
				byte_done_flag_r <=0;
				wr_data_shift_r <=0;
				wr_data_r<=0;
        end
        default: begin
            state_r <= IDLE;
            wr_flag_r <=0;
            rd_flag_r <=0;
				byte_done_flag_r <=0;
				wr_data_shift_r <=0;
				wr_data_r<=0;
        end
        endcase
    end 
end
//三台门控制端
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i2c_de_r <= 1'b0;
    end
    else begin
        case(state_r)
        IDLE:;
        RD_START,WR_START:i2c_de_r <=1;
		  WR_DEV_ADDR,WR_REG_ADDR,WR_DATA:begin   
            if(hilow_cnt_r <16)begin
                i2c_de_r <=1;
            end
            else  i2c_de_r <=0;
        end
        RD_DATA:begin
            if (hilow_cnt_r <16) begin
                i2c_de_r <=0;
            end
            else i2c_de_r <=1;
        end
        STOP: i2c_de_r <=0;
        default:i2c_de_r <=0;
        endcase  
    end
end
//读写完成标志
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_done_r <= 0;
        rd_done_r <= 0;
    end
    else begin
        case(state_r)
        IDLE,WR_START,WR_DEV_ADDR,WR_REG_ADDR,STOP:;
        WR_DATA:begin
            if (hilow_cnt_r ==17) begin
                wr_done_r <=1;
            end
            else wr_done_r <=0;
        end
        RD_DATA:begin
            if (hilow_cnt_r ==17) begin
                rd_done_r <=1;
            end
            else rd_done_r <=0;
        end
        default:begin
            wr_done_r <= 0;
            rd_done_r <= 0;  
        end 
        endcase  
    end
end
//发送8bit数据
task i2c_send_data;begin
	  if (hilow_cnt_r <17) begin
			wr_data_shift_r <= wr_data_r[7];
			if(scl_low_r)begin
				wr_data_r <= {wr_data_r[6:0],1'b0};
			end
			else wr_data_r <= wr_data_r;
	  end
	  else begin
			byte_done_flag_r <=1;
			wr_data_shift_r <=0;
	  end
end
endtask 
//接受8bit数据
task i2c_rec_data;begin
	if(hilow_cnt_r <17)begin
		rd_data_r[0] <= i2c_sda;
		if(scl_low_r)begin
			rd_data_r <= {rd_data_r[6:0],i2c_sda};
		end
		else rd_data_r <= rd_data_r;
	end
	else begin
		byte_done_flag_r <= 1;
	end
end
endtask
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        i2c_sda_r <=1;
    end
    else begin
        i2c_sda_r <= i2c_de_r ? wr_data_shift_r:1'bz; 
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ack_r <=0;
        non_ack_r <=0;
    end
    else if ((state_r == WR_DEV_ADDR) | (state_r == WR_REG_ADDR) | (state_r == WR_DATA)) begin
        non_ack_r <=0;
		  if (hilow_cnt_r >15 ) begin
            ack_r <= i2c_sda;
        end
        else ack_r <= 0;
    end
    else if (state_r ==RD_DATA) begin
		  ack_r <=0;
        if (hilow_cnt_r >15 ) begin
            non_ack_r <= 1;
        end
        else non_ack_r<=0;
    end
	 else begin
		non_ack_r <= 0;
		ack_r		 <= 0;
	 end
end
assign rd_data = rd_data_r;
assign wr_done = wr_done_r;
assign rd_done = rd_done_r;
assign i2c_sda = i2c_sda_r;
assign i2c_scl = i2c_scl_r;
endmodule