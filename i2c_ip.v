///////////////////////////////////////////////////////////////////////////////
// COPYRIGHT(c)2024, GENERTEC GUOCE TIME GRATING TECHNOLOGY CO.,LTD.
// All rights reserved.
// File name   : i2c_ip.v
// Author      : ChaoyaWang
// Date        : 2024-09-25
// Version     : 0.1
// Description : i2c_ip核
// 
// 
// 
// Modification History:
//   Date       |   Author      |   Version     |   Change Description
//==============================================================================
// 2024-09-25   |    ChaoyaWang  |     0.1        | Base Version
////////////////////////////////////////////////////////////////////////////////
module i2c_ip
#(
    parameter                                        SYS_CLK        = 50_000_000,
    parameter                                        SCL_CLK        = 400_000

)
(
    input                                      clk             ,//系统时钟
    input                                      rst_n           ,//复位,低有效
    //控制信号
    input                                      wr_req          ,//写请求
    input                                      rd_req          ,//读请求
    input        [   1: 0]                     wr_addr_lenth   ,//写地址长度
    input        [   7: 0]                     wr_data         ,//写数据
    //input [7:0]wr_addr,//写地址
    output       [   7: 0]                     rd_data         ,//读数据
    output                                     rd_done         ,//读完成
    output                                     wr_done         ,//写完成
    //I2C信号
    output                                     i2c_scl         ,//I2C 时钟
    inout                                      i2c_sda         ,//I2C 数据
    output                                     is_out           //输出使能控制信号
);
    parameter                                        SCL_CNT        = SYS_CLK/SCL_CLK;
    parameter                                        IDLE           = 8'b0000_0001;
    parameter                                        WR_START       = 8'b0000_0010;
    parameter                                        WR_DEV_ADDR    = 8'b0000_0100;
    parameter                                        WR_REG_ADDR    = 8'b0000_1000;
    parameter                                        WR_DATA        = 8'b0001_0000;
    parameter                                        RD_START       = 8'b0010_0000;
    parameter                                        RD_DATA        = 8'b0100_0000;
    parameter                                        STOP           = 8'b1000_0000;

    reg                                        rI2cScl         ;//i2c时钟寄存器
    reg          [   6: 0]                     rSclCnt         ;
    reg                                        rI2cValid       ;//i2c操作有效信号,以显示i2c总线处于忙状态
    reg          [   4: 0]                     rHiLowCnt       ;
    reg          [   7: 0]                     rRdData         ;
    reg          [   7: 0]                     rState          ;
    reg                                        rI2cSda         ;
    reg                                        rWrFlag         ;//写标志
    reg                                        rRdFlag         ;//读标志
    reg                                        rI2cDe          ;//I2C总线方向控制标志
    reg                                        rWrDone         ;
    reg                                        rRdDone         ;
    reg          [   7: 0]                     rWrData         ;
    reg                                        rAck,rNonAck    ;
    reg                                        rWrDataShift    ;
    reg                                        rByteDoneFlag   ;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        rSclCnt <= 0;
    end
    else if(rI2cValid)begin
        if (rSclCnt == SCL_CNT) begin
        rSclCnt <= 0;
        end
        else rSclCnt <= rSclCnt +1;
     end
     else rSclCnt <=0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        rI2cScl <= 1;
    end
    else if(rSclCnt == SCL_CNT >>1)begin
        rI2cScl <= 0;
    end
    else if(rSclCnt ==0)begin
         rI2cScl <= 1;
    end
    else rI2cScl = rI2cScl;
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rI2cValid <=0;
    end
    else if (wr_req | rd_req) begin
        rI2cValid <=1;
    end
    else if (rd_done | wr_done) begin
        rI2cValid <=0;
    end
end
    reg                                        scl_high_r,scl_low_r  ;//SCL低电平和高电平位置标志
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scl_high_r <= 0;
    end
    else if (rI2cValid) begin
        if (rSclCnt == (SCL_CNT >>2)) begin
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
    else if (rI2cValid) begin
        if (rSclCnt == ((SCL_CNT >>1 )+(SCL_CNT >>2))) begin
            scl_low_r <=1;
        end
        else scl_low_r <=0;
    end
    else scl_low_r <=0;
end
//i2c有效期间高低电平计数器

always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        rHiLowCnt <=0;
    end
    else if ((rState == WR_DEV_ADDR) |(rState == WR_REG_ADDR) | (rState == WR_DATA)
        | (rState == RD_DATA)) begin
        if(scl_low_r)begin
            if (rHiLowCnt == 8) begin
                rHiLowCnt <= 0;
            end
            else begin
                rHiLowCnt <= rHiLowCnt+1;
            end
        end
        else rHiLowCnt <= rHiLowCnt;
    end
    else rHiLowCnt <=0;
end

//状态机
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        rState <= IDLE;
        rWrFlag <=0;
        rRdFlag <=0;
        rByteDoneFlag <=0;
        rWrDataShift <=0;
        rWrData<=0;
        rRdData<=0;
    end
    else begin
        case(rState)
        IDLE:begin
            rWrFlag <=0;
            rRdFlag <=0;
            rByteDoneFlag <=0;
            rWrDataShift <=0;
            rWrData<=0;
            rRdData<=0;
            if (wr_req) begin
                rState <= WR_START;
            end
            else if(rd_req)begin
                rState <= RD_START;
            end
            else rState <= IDLE;
        end
        WR_START:begin
            if(wr_req)begin
                rWrFlag <=1;
                if(scl_high_r)begin
                    rState <= WR_START;
                end
                else if (scl_low_r)begin
                    rState <= WR_DEV_ADDR;
                    rWrData <= wr_data;
                end
                else rState <= WR_START;
            end
            else rState <= IDLE;
        end
        WR_DEV_ADDR:begin
            if(wr_req | rd_req)begin
                if(rByteDoneFlag && ~rAck && scl_low_r)begin
                    rState <= WR_REG_ADDR;
                    rWrData <= wr_data;
                end
                else begin
                    i2c_send_data;
                end
            end
            else rState <= IDLE;
        end
        WR_REG_ADDR:begin
            if(wr_req)begin
                if(rByteDoneFlag && ~rAck && scl_low_r)begin
                    rState     <= WR_DATA;
                    rWrData   <= wr_data;
                end
                else begin
                    i2c_send_data;
                end
            end
            else if (rd_req) begin
                if(rByteDoneFlag && ~rAck && scl_low_r)begin
                    rState     <= RD_DATA;
                    rWrData   <= wr_data;
                end
                else begin
                    i2c_send_data;
                end
            end
            else rState <= IDLE;
          end
        WR_DATA:begin
            if(wr_req)begin
                if(rByteDoneFlag && ~rAck && scl_low_r)begin
                    rState     <= WR_DATA;
                    rWrData   <= wr_data;
                end
                else begin
                    i2c_send_data;
                end
            end
            else rState <= IDLE;
          end
        RD_START:begin
            if(rd_req)begin
                rRdFlag <=1;
                if (scl_high_r) begin
                    rState <= RD_START;
                end
                else if(scl_low_r)begin
                        rState <= WR_DEV_ADDR;
                        rWrData <= wr_data;
                end
                else rState <= RD_START;
            end
            else rState <= IDLE;
        end
        RD_DATA:begin
            if(rd_req)begin
                if(rByteDoneFlag && ~rAck && scl_low_r)begin
                    rState     <= STOP;
                end
                else begin
                    i2c_rec_data;
                end
            end
            else rState <= IDLE;
        end
        STOP:begin
            rState <= IDLE;
            rWrFlag <=0;
            rRdFlag <=0;
            rByteDoneFlag <=0;
            rWrDataShift <=0;
            rWrData<=0;
        end
        default: begin
            rState <= IDLE;
            rWrFlag <=0;
            rRdFlag <=0;
            rByteDoneFlag <=0;
            rWrDataShift <=0;
            rWrData<=0;
        end
        endcase
    end
end
//三台门控制端
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rI2cDe <= 1'b0;
    end
    else begin
        case(rState)
        IDLE:;
        RD_START,WR_START:rI2cDe <=1;
          WR_DEV_ADDR,WR_REG_ADDR,WR_DATA:begin
            if(rHiLowCnt <=7)begin
                rI2cDe <=1;
            end
            else  rI2cDe <=0;
        end
        RD_DATA:begin
            if (rHiLowCnt <=7) begin
                rI2cDe <=0;
            end
            else rI2cDe <=1;
        end
        STOP: rI2cDe <=0;
        default:rI2cDe <=0;
        endcase
    end
end
//读写完成标志
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rWrDone <= 0;
        rRdDone <= 0;
    end
    else begin
        case(rState)
        IDLE,WR_START,STOP:;
        WR_DATA,WR_DEV_ADDR,WR_REG_ADDR:begin
            if (rHiLowCnt ==8) begin
                rWrDone <=1;
            end
            else rWrDone <=0;
        end
        RD_DATA:begin
            if (rHiLowCnt ==8) begin
                rRdDone <=1;
            end
            else rRdDone <=0;
        end
        default:begin
            rWrDone <= 0;
            rRdDone <= 0;
        end
        endcase
    end
end
//发送8bit数据
task i2c_send_data;begin
      if (rHiLowCnt <=7) begin
        rWrDataShift <= rWrData[7];
        if(scl_low_r)begin
            rWrData <= {rWrData[6:0],1'b0};
        end
        else rWrData <= rWrData;
      end
      else if (rHiLowCnt ==8)begin
        rByteDoneFlag <=1;
        rWrDataShift <=0;
      end
      else if (rHiLowCnt >8)begin
        rByteDoneFlag <= 0;
      end
end
endtask
//接受8bit数据
task i2c_rec_data;begin
    if(rHiLowCnt <=7)begin
        rRdData[0] <= i2c_sda;
        if(scl_low_r)begin
            rRdData <= {rRdData[6:0],i2c_sda};
        end
        else rRdData <= rRdData;
    end
    else if (rHiLowCnt ==8)begin
        rByteDoneFlag <= 1;
    end
    else if (rHiLowCnt >8)begin
        rByteDoneFlag <= 0;
    end
end
endtask
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rI2cSda <=1;
    end
    else begin
        rI2cSda <= rI2cDe ? rWrDataShift:1'bz;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rAck <=1;
        rNonAck <=0;
    end
    else if ((rState == WR_DEV_ADDR) | (rState == WR_REG_ADDR) | (rState == WR_DATA)) begin
        rNonAck <=0;
        if (rHiLowCnt ==8 ) begin
            rAck <= 0;                                              //i2c_sda;
        end
        else rAck <= 1;
    end
    else if (rState ==RD_DATA) begin
        rAck <=1;
        if (rHiLowCnt ==8 ) begin
            rNonAck <= 1;
        end
        else rNonAck<=0;
    end
    else begin
        rNonAck <= 0;
        rAck     <= 1;
    end
end
    assign                                           rd_data        = rRdData;
    assign                                           wr_done        = rWrDone;
    assign                                           rd_done        = rRdDone;
    assign                                           i2c_sda        = rI2cSda;
    assign                                           i2c_scl        = rI2cScl;
    assign                                           is_out         = rI2cDe;
endmodule