#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>

const char *bit_rep[16] = {
    [ 0] = "0000", [ 1] = "0001", [ 2] = "0010", [ 3] = "0011",
    [ 4] = "0100", [ 5] = "0101", [ 6] = "0110", [ 7] = "0111",
    [ 8] = "1000", [ 9] = "1001", [10] = "1010", [11] = "1011",
    [12] = "1100", [13] = "1101", [14] = "1110", [15] = "1111",
};

void print_byte(uint8_t byte)
{
    printf("%s%s", bit_rep[byte >> 4], bit_rep[byte & 0x0F]);
}


typedef struct {
    char a: 1;
    char b: 1;
    char c: 1;
    char d: 1;
    char e: 1;
    char f: 1;
    char g: 1;
    char h: 1;
} bitword;

typedef struct {
    char a: 1;
    char :0;
    char c: 1;
} bitword_unnamed;

// Copied from https://learn.microsoft.com/en-us/cpp/c-language/c-bit-fields?view=msvc-170
struct tricky_bits
{
    unsigned int first : 9;
    unsigned int second : 7;
    unsigned int may_straddle : 30;
    unsigned int last : 18;
} ;


struct mixing_bits {
    unsigned first;
    char b0_0: 1;
    char b0_1: 1;
    char b0_2: 1;
    unsigned second;
    unsigned int b1_0: 3;
    unsigned int b1_1: 4;
    unsigned int b1_2: 1;
    short third;
};

int main() {
    bitword w0 = {.a = -1};
    uint8_t backing0 = *(uint8_t *)(&w0);
    bool reverse = (backing0 & 0b10000000) > 0; // The bits allocates from MSB to LSB

    bitword_unnamed w1 = {.c = -1, .a = -1};
    uint16_t backing1 = *(uint16_t *)(&w1);
    bool unnamed_void_boundary = (backing0 & (reverse ? 0b100000001000000 : 0b0000000100000001)) > 0;

    bool not_straddle = sizeof(struct tricky_bits) == 12;
    bool straddle = sizeof(struct tricky_bits) == 8;

    bool collpse_padding = sizeof(struct mixing_bits) == 20;
    bool not_collpse_padding = sizeof(struct mixing_bits) == 16;

    printf(".{\n  .reverse_bits=%s,\n", reverse ? "true" : "false");
    printf("  .unnamed_void_boundary=%s,\n", unnamed_void_boundary ? "true" : "false");
    printf("  .straddle = %s,\n", straddle ? "true" : (not_straddle ? "false" : "@compilerError(\"straddle test failed\")"));
    printf("  .collapse_padding = %s,\n",
        collpse_padding ? "true" : (
            not_collpse_padding ? "false" : "@compilerError(\"collapse padding test failed\")"
        )
    );
    printf("}\n");
}
