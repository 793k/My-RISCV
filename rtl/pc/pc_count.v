`timescale 1ns / 1ps

//****************************************VSCODE PLUG-IN**********************************//
//----------------------------------------------------------------------------------------
// IDE :                   VSCODE     
// VSCODE plug-in version: Verilog-Hdl-Format-4.3.20260413
// VSCODE plug-in author : Jiang Percy
//----------------------------------------------------------------------------------------
//****************************************Copyright (c)***********************************//
// Copyright(C)            Please Write Company name
// All rights reserved     
// File name:              pc_count
// Last modified Date:     2026/05/21 14:08:08
// Last Version:           V1.0
// Descriptions:           
//----------------------------------------------------------------------------------------
// Created by:             Please Write You Name 
// Created date:           2026/05/21 14:08:08
// mail      :             Please Write mail 
// Version:                V1.0
// TEXT NAME:              pc_count.v
// PATH:                   D:\study_for_fpga\CPU\rtl\pc\pc_count.v
// Descriptions:           
//                         
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module pc_count #(
    parameter AW = 32
) (
    input  wire clk,
    input  wire rst_n,
    input  wire jump_en,
    input  wire [AW-1:0] jump_addr,
    output reg  [AW-1:0] out_addr
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) out_addr <= 0;
        else if (jump_en == 1) out_addr <= jump_addr;
        else out_addr <= out_addr + 32'd4;
    end

endmodule

