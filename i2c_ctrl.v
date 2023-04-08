////////////////////////////////////////////////////////
// project: i2c_ctrl
// module : i2c_ctrl
// author : Charles
// date   : 2020/10/10
// version: 1.0
///////////////////////////////////////////////////////
module i2c_ctrl(
    input clk,
    input rst_n,

    //控制信号
    input rd_req,
    input wr_req,
    input [7:0]wr_data,
    input [7:0]wr_addr,
    output [7:0]rd_data,
    output rd_done,
    output wr_done,

    output i2c_scl,
    inout i2c_sda
);

i2c_ip u1(
.clk(clk),//系统时钟
.rst_n(rst_n),//复位,低有效

.wr_req(wr_req),//写请求
.rd_req(rd_req),//读请求
.wr_addr_lenth(),//写地址长度
.wr_data(wr_data),//写数据
//.wr_addr(wr_addr),//写地址
.rd_data(rd_data),//读数据
.rd_done(rd_done),//读完成
.wr_done(wr_done),//写完成

.i2c_scl(i2c_scl),//I2C 时钟
.i2c_sda(i2c_sda) //I2C 数据
);

endmodule