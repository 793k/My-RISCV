`timescale 1ns / 1ps

// ============================================================
// PC 计数器模块
// ============================================================
// 功能：每周期自增 4，支持跳转时加载目标地址
// ============================================================

module pc_count #(
    parameter AW = 32
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        jump_en,
    input  wire [AW-1:0] jump_addr,
    output reg  [AW-1:0] out_addr
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            out_addr <= 0;
        else if (jump_en == 1)
            out_addr <= jump_addr;
        else
            out_addr <= out_addr + 32'd4;
    end

endmodule
