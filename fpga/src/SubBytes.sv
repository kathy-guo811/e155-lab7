// Kathy Guo
// kaguo@g.hmc.edu
// 10/27/2026
// SubBytes module calls the sbox_sync module to replace each byte using the AES S-box.

module SubBytes(
    input logic clk,
    input logic [2:0] byte_group,
    input logic [127:0] state_in,
    output logic [127:0] state_out);

    logic [31:0] selected_bytes;
    logic [31:0] sub_bytes;
    
    always_comb begin
        case (byte_group)
            3'd0: selected_bytes = state_in[127:96];
            3'd1: selected_bytes = state_in[95:64];
            3'd2: selected_bytes = state_in[63:32];
            3'd3: selected_bytes = state_in[31:0];
            default: selected_bytes = 32'b0;
        endcase
    end
    
    always_ff @(posedge clk) begin
        case (byte_group)
            3'd2: state_out[127:96] <= sub_bytes;
            3'd3: state_out[95:64]  <= sub_bytes;
            3'd4: state_out[63:32]  <= sub_bytes;
            3'd5: state_out[31:0]   <= sub_bytes;
            default: ;
        endcase
    end

    sbox_sync s0(
        .clk(clk),
        .a(selected_bytes[31:24]),
        .y(sub_bytes[31:24])
    );

    sbox_sync s1(
        .clk(clk),
        .a(selected_bytes[23:16]),
        .y(sub_bytes[23:16])
    );

    sbox_sync s2(
        .clk(clk),
        .a(selected_bytes[15:8]),
        .y(sub_bytes[15:8])
    );

    sbox_sync s3(
        .clk(clk),
        .a(selected_bytes[7:0]),
        .y(sub_bytes[7:0])
    );

endmodule