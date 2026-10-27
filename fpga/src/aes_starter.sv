/////////////////////////////////////////////
// aes
//   Top level module with SPI interface and SPI core
/////////////////////////////////////////////

module aes(input  logic clk,
           input  logic sck, 
           input  logic sdi,
           output logic sdo,
           input  logic load,
           output logic done);
                    
    logic [127:0] key, plaintext, cyphertext;
            
    aes_spi spi(sck, sdi, sdo, done, key, plaintext, cyphertext);   
    aes_core core(clk, load, key, plaintext, done, cyphertext);
endmodule

/////////////////////////////////////////////
// aes_spi
//   SPI interface.  Shifts in key and plaintext
//   Captures ciphertext when done, then shifts it out
//   Tricky cases to properly change sdo on negedge clk
/////////////////////////////////////////////

module aes_spi(input  logic sck, 
               input  logic sdi,
               output logic sdo,
               input  logic done,
               output logic [127:0] key, plaintext,
               input  logic [127:0] cyphertext);

    logic         sdodelayed, wasdone;
    logic [127:0] cyphertextcaptured;
               
    // assert load
    // apply 256 sclks to shift in key and plaintext, starting with plaintext[127]
    // then deassert load, wait until done
    // then apply 128 sclks to shift out cyphertext, starting with cyphertext[127]
    // SPI mode is equivalent to cpol = 0, cpha = 0 since data is sampled on first edge and the first
    // edge is a rising edge (clock going from low in the idle state to high).
    always_ff @(posedge sck)
        if (!wasdone)  {cyphertextcaptured, plaintext, key} = {cyphertext, plaintext[126:0], key, sdi};
        else           {cyphertextcaptured, plaintext, key} = {cyphertextcaptured[126:0], plaintext, key, sdi}; 
    
    // sdo should change on the negative edge of sck
    always_ff @(negedge sck) begin
        wasdone = done;
        sdodelayed = cyphertextcaptured[126];
    end
    
    // when done is first asserted, shift out msb before clock edge
    assign sdo = (done & !wasdone) ? cyphertext[127] : sdodelayed;
endmodule

/////////////////////////////////////////////
// aes_core
//   top level AES encryption module
//   when load is asserted, takes the current key and plaintext
//   generates cyphertext and asserts done when complete 11 cycles later
// 
//   See FIPS-197 with Nk = 4, Nb = 4, Nr = 10
//
//   The key and message are 128-bit values packed into an array of 16 bytes as
//   shown below
//        [127:120] [95:88] [63:56] [31:24]     S0,0    S0,1    S0,2    S0,3
//        [119:112] [87:80] [55:48] [23:16]     S1,0    S1,1    S1,2    S1,3
//        [111:104] [79:72] [47:40] [15:8]      S2,0    S2,1    S2,2    S2,3
//        [103:96]  [71:64] [39:32] [7:0]       S3,0    S3,1    S3,2    S3,3
//
//   Equivalently, the values are packed into four words as given
//        [127:96]  [95:64] [63:32] [31:0]      w[0]    w[1]    w[2]    w[3]
/////////////////////////////////////////////

module aes_core(input  logic         clk, 
                input  logic         load,
                input  logic [127:0] key, 
                input  logic [127:0] plaintext, 
                output logic         done, 
                output logic [127:0] cyphertext);

    // TODO: Your code goes here
    logic [127:0] state_reg;
    logic [127:0] key_reg;
    logic [127:0] ark_out;

    logic [127:0] sr_out;

    logic [127:0] sb_out;
    logic [2:0] byte_group;

    always_ff @(posedge clk) begin
        if (load) begin
            state_reg <= plaintext;
            key_reg <= key;
        end
    end

    AddRoundKey ark(
        .state_in(state_reg),
        .round_key(key_reg),
        .state_out(ark_out));
    
    SubBytes sb(
        .clk(clk),
        .byte_group(byte_group),
        .state_in(state_reg),
        .state_out(sb_out));

    ShiftRows sr(
        .state_in(sb_out),
        .state_out(sr_out));

endmodule

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
            3'd1: state_out[127:96] <= sub_bytes;
            3'd2: state_out[95:64]  <= sub_bytes;
            3'd3: state_out[63:32]  <= sub_bytes;
            3'd4: state_out[31:0]   <= sub_bytes;
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

module ShiftRows(
    input logic [127:0] state_in,
    output logic [127:0] state_out);

    assign state_out [127:96] = {
        state_in [127:120],
        state_in [87:80],
        state_in [47:40],
        state_in [7:0]};

    assign state_out [95:64] = {
        state_in [95:88],
        state_in [55:48],
        state_in [15:8],
        state_in [103:96]};
    
    assign state_out [63:32] = {
        state_in [63:56],
        state_in [23:16],
        state_in [111:104],
        state_in [71:64]};

    assign state_out [31:0] = {
        state_in [31:24],
        state_in [119:112],
        state_in [79:72],
        state_in [39:32]};
endmodule

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

    key_out = {w0p, w1p, w2p, w3p};

endmodule

module AddRoundKey(
    input logic [127:0] state_in,
    input logic [127:0] round_key,
    output logic [127:0] state_out);

    assign state_out = state_in ^ round_key;
endmodule

/////////////////////////////////////////////
// sbox
//   Infamous AES byte substitutions with magic numbers
//   Combinational version which is mapped to LUTs (logic cells)
//   Section 5.1.1, Figure 7
/////////////////////////////////////////////

module sbox(input  logic [7:0] a,
            output logic [7:0] y);
            
  // sbox implemented as a ROM
  // This module is combinational and will be inferred using LUTs (logic cells)
  logic [7:0] sbox[0:255];

  initial   $readmemh("src/sbox.txt", sbox);
  assign y = sbox[a];
endmodule

/////////////////////////////////////////////
// sbox
//   Infamous AES byte substitutions with magic numbers
//   Synchronous version which is mapped to embedded block RAMs (EBR)
//   Section 5.1.1, Figure 7
/////////////////////////////////////////////
module sbox_sync(
	input		logic [7:0] a,
	input	 	logic 			clk,
	output 	logic [7:0] y);
            
  // sbox implemented as a ROM
  // This module is synchronous and will be inferred using BRAMs (Block RAMs)
  logic [7:0] sbox [0:255];

  initial   $readmemh("sbox.txt", sbox);
	
	// Synchronous version
	always_ff @(posedge clk) begin
		y <= sbox[a];
	end
endmodule

/////////////////////////////////////////////
// mixcolumns
//   Even funkier action on columns
//   Section 5.1.3, Figure 9
//   Same operation performed on each of four columns
/////////////////////////////////////////////

module mixcolumns(input  logic [127:0] a,
                  output logic [127:0] y);

  mixcolumn mc0(a[127:96], y[127:96]);
  mixcolumn mc1(a[95:64],  y[95:64]);
  mixcolumn mc2(a[63:32],  y[63:32]);
  mixcolumn mc3(a[31:0],   y[31:0]);
endmodule

/////////////////////////////////////////////
// mixcolumn
//   Perform Galois field operations on bytes in a column
//   See EQ(4) from E. Ahmed et al, Lightweight Mix Columns Implementation for AES, AIC09
//   for this hardware implementation
/////////////////////////////////////////////

module mixcolumn(input  logic [31:0] a,
                 output logic [31:0] y);
                      
        logic [7:0] a0, a1, a2, a3, y0, y1, y2, y3, t0, t1, t2, t3, tmp;
        
        assign {a0, a1, a2, a3} = a;
        assign tmp = a0 ^ a1 ^ a2 ^ a3;
    
        galoismult gm0(a0^a1, t0);
        galoismult gm1(a1^a2, t1);
        galoismult gm2(a2^a3, t2);
        galoismult gm3(a3^a0, t3);
        
        assign y0 = a0 ^ tmp ^ t0;
        assign y1 = a1 ^ tmp ^ t1;
        assign y2 = a2 ^ tmp ^ t2;
        assign y3 = a3 ^ tmp ^ t3;
        assign y = {y0, y1, y2, y3};    
endmodule

/////////////////////////////////////////////
// galoismult
//   Multiply by x in GF(2^8) is a left shift
//   followed by an XOR if the result overflows
//   Uses irreducible polynomial x^8+x^4+x^3+x+1 = 00011011
/////////////////////////////////////////////

module galoismult(input  logic [7:0] a,
                  output logic [7:0] y);

    logic [7:0] ashift;
    
    assign ashift = {a[6:0], 1'b0};
    assign y = a[7] ? (ashift ^ 8'b00011011) : ashift;
endmodule