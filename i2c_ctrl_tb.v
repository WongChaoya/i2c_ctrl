///////////////////////////////////////////////////////////////////////////////
// COPYRIGHT(c)2024, GENERTEC GUOCE TIME GRATING TECHNOLOGY CO.,LTD.
// All rights reserved.
// File name   : i2c_ctrl.v
// Author      : ChaoyaWang
// Date        : 2024-09-25
// Version     : 0.1
// Description : Si5341A I2C配置总线
// 
// 
// 
// Modification History:
//   Date       |   Author      |   Version     |   Change Description
//==============================================================================
// 2024-09-25   |    ChaoyaWang  |     0.1        | Base Version
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ns
module i2c_ctrl_tb();

    reg                                        clk             ;
    reg                                        rst_n           ;

    //控制信号
    reg                                        rd_req          ;
    reg                                        wr_req          ;
    reg          [   7: 0]                     wr_data         ;
    wire         [   7: 0]                     rd_data         ;
    wire                                       rd_done         ;
    wire                                       wr_done         ;
    reg          [   7: 0]                     rByteCnt        ; 
    reg          [   7: 0]                     rBitCnt         ;
    wire                                       i2c_scl         ;
    wire                                       is_out          ;
    // wire                                       i2c_sda_en     ;
    wire                                       i2c_sda       ;
    reg                                        i2c_sda_reg     ;
    parameter                                        DEV_ADDR       = 8'he8 ;
    parameter                                        DATA           = 8'hAA ;
always #10 clk = ~clk;
initial begin
    clk         = 0;
    rst_n       = 0;
    rd_req      = 0;
    wr_req      = 0;
    rByteCnt    = 0;
    rBitCnt     = 0;
    wr_data     = 8'h00;
    i2c_sda_reg = 1'b1;
    #200 rst_n  = 1;

end
always @(posedge clk) begin
    if (!is_out) begin
        i2c_sda_reg = 1'b0;
    end
    else begin
        i2c_sda_reg = 1'b1;
    end
end
always @(posedge clk) begin
    
    case (rByteCnt)
        0: begin
            wr_req  =    1'b1;
            wr_data =    8'hE8;
            @ (posedge wr_done) begin
                wr_data =    8'h00;
                rByteCnt    = rByteCnt  +1;
            end
        end
        1: begin
            @ (posedge wr_done) begin
                 wr_data =    8'h00;
                rByteCnt    = rByteCnt  +1;
            end
        end
        2: begin
            @ (posedge wr_done) begin
                wr_data =    DATA;
                rBitCnt = 0;
                rByteCnt    = rByteCnt  +1;
            end
        end
        3: begin
           @ (posedge wr_done) begin
                rBitCnt = 0;
                rByteCnt    = rByteCnt  +1;
            end
        end
        4: begin
            wr_req  =    1'b0;
            #1000;
            $stop;
        end
        default: ;
    endcase

end

//--------------------------------------------------------------------------
//--    状态机名称查看器
//--------------------------------------------------------------------------
//1个ASSIC码字符宽度是8位，例如“IDLE”有4个字符则需要32位宽
	reg [87:0]              Min_State_MACHINE          ;
	
	localparam 	//这段参数声明是一定要有的，否则在仿真时会报未声明变量的错误，如下图
                                          IDLE           = 8'b0000_0001,
                                          WR_START       = 8'b0000_0010,
                                          WR_DEV_ADDR    = 8'b0000_0100,
                                          WR_REG_ADDR    = 8'b0000_1000,
                                          WR_DATA        = 8'b0001_0000,
                                          RD_START       = 8'b0010_0000,
                                          RD_DATA        = 8'b0100_0000,
                                          STOP           = 8'b1000_0000;
			
	always @(*) begin
		case(i2c_ctrl_inst.u1.rState)
            IDLE        :     Min_State_MACHINE = "IDLE";
            WR_START    :     Min_State_MACHINE = "WR_START";
            WR_DEV_ADDR :     Min_State_MACHINE = "WR_DEV_ADDR";
            WR_REG_ADDR :     Min_State_MACHINE = "WR_REG_ADDR";
            WR_DATA     :     Min_State_MACHINE = "WR_DATA";
            RD_START    :     Min_State_MACHINE = "RD_START";
            RD_DATA     :     Min_State_MACHINE = "RD_DATA";
            STOP        :     Min_State_MACHINE = "STOP";
			default     :     Min_State_MACHINE = "IDLE ";
		endcase
	end



i2c_ctrl
#(
    .SYS_CLK                                         (50_000_000     ),
    .SCL_CLK                                         (400_000        ) 
)
i2c_ctrl_inst(
    .clk                                             (clk            ),
    .rst_n                                           (rst_n          ),

    
    .rd_req                                          (rd_req         ),
    .wr_req                                          (wr_req         ),
    .wr_data                                         (wr_data        ),
    // .wr_addr                                         (wr_addr        ),
    .rd_data                                         (rd_data        ),
    .rd_done                                         (rd_done        ),
    .wr_done                                         (wr_done        ),

    .i2c_scl                                         (i2c_scl        ),
    .i2c_sda                                         (i2c_sda        ),
    .is_out                                          (is_out         ) 
);

    assign                                           i2c_sda       = (!is_out) ? i2c_sda_reg : 1'bz;

endmodule