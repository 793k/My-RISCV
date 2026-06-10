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
    input  wire [AW-1:0] target,
    output reg  [AW-1:0] pc
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 0;
        else if (jump_en == 1)
            pc <= target;
        else
            pc <= pc + 32'd4;
    end

endmodule
