// Kathy Guo
// kaguo@g.hmc.edu
// 10/27/2026
// KeyExpansion module takes the original cipher key as input, and generate the next key for the next round of encryption
// through rot_word (shifts the bytes leftward by 1), sub_word (passes each byte of the rotated word through SubByte),
// and XORs the result with a rcon (round-dependent constant value) to generate a new encryption key for the next round.

module KeyExpansion(
    input clk,
    input logic [127:0] key_in,
    input logic [3:0] round,
    output logic [127:0] key_out);

    logic [31:0] w0, w1, w2, w3;
    logic [31:0] rot_word;
    logic [31:0] sub_word;
    logic [31:0] rcon;
    logic [31:0] temp;
    logic [31:0] w0p, w1p, w2p, w3p;

    assign w0 = key_in[127:96];
    assign w1 = key_in[95:64];
    assign w2 = key_in[63:32];
    assign w3 = key_in[31:0];
    assign rot_word = {w3[23:0], w3[31:24]};

    sbox_sync sw0(
        .clk(clk),
        .a(rot_word[31:24]),
        .y(sub_word[31:24])
    );

    sbox_sync sw1(
        .clk(clk),
        .a(rot_word[23:16]),
        .y(sub_word[23:16])
    );

    sbox_sync sw2(
        .clk(clk),
        .a(rot_word[15:8]),
        .y(sub_word[15:8])
    );

    sbox_sync sw3(
        .clk(clk),
        .a(rot_word[7:0]),
        .y(sub_word[7:0])
    );

    always_comb begin
        case(round)
            4'd1: rcon = 32'h01000000;
            4'd2: rcon = 32'h02000000;
            4'd3: rcon = 32'h04000000;
            4'd4: rcon = 32'h08000000;
            4'd5: rcon = 32'h10000000;
            4'd6: rcon = 32'h20000000;
            4'd7: rcon = 32'h40000000;
            4'd8: rcon = 32'h80000000;
            4'd9: rcon = 32'h1b000000;
            4'd10: rcon = 32'h36000000;
            default: rcon = 32'h00000000;
        endcase
    end

    assign temp = sub_word ^ rcon;
    assign w0p = w0 ^ temp;
    assign w1p = w1 ^ w0p;
    assign w2p = w2 ^ w1p;
    assign w3p = w3 ^ w2p;

    assign key_out = {w0p, w1p, w2p, w3p};

endmodule