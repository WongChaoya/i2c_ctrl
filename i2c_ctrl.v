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
module i2c_ctrl #(
    parameter                                        SYS_CLK        = 50_000_000,
    parameter                                        SCL_CLK        = 400_000
)
(
    input                                      clk             ,
    input                                      rst_n           ,

    //控制信号
    input                                      rd_req          ,
    input                                      wr_req          ,
    input        [   7: 0]                     wr_data         ,
    // input        [   7: 0]                     wr_addr         ,
    output       [   7: 0]                     rd_data         ,
    output                                     rd_done         ,
    output                                     wr_done         ,

    output                                     i2c_scl         ,
    inout                                      i2c_sda         ,
    output                                     is_out          
);

i2c_ip #(
    .SYS_CLK                                         (SYS_CLK        ),
    .SCL_CLK                                         (SCL_CLK        ) 
)
u1(
    .clk                                             (clk            ),//系统时钟
    .rst_n                                           (rst_n          ),//复位,低有效

    .wr_req                                          (wr_req         ),//写请求
    .rd_req                                          (rd_req         ),//读请求
    // .wr_addr_lenth                                   (               ),//写地址长度
    .wr_data                                         (wr_data        ),//写数据
    .rd_data                                         (rd_data        ),//读数据
    .rd_done                                         (rd_done        ),//读完成
    .wr_done                                         (wr_done        ),//写完成

    .i2c_scl                                         (i2c_scl        ),//I2C 时钟
    .i2c_sda                                         (i2c_sda        ), //I2C 数据
    .is_out                                          (is_out         )
);

endmodule