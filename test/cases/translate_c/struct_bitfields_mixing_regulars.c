typedef struct {
    signed int v0;
    unsigned b0: 1;
    unsigned b1: 1;
    unsigned b2: 1;
} word;

// translate-c
// c_frontend=clang
//
// pub const word = @import("std").zig.c_translation.EmulateBitfieldStruct(struct {
//     v0: c_int = @import("std").mem.zeroes(c_int),
//     b0: u1 = @import("std").mem.zeroes(u1),
//     b1: u1 = @import("std").mem.zeroes(u1),
//     b2: u1 = @import("std").mem.zeroes(u1),
// }, &([4]type{
//     void,
//     c_uint,
//     c_uint,
//     c_uint,
// }), .{});