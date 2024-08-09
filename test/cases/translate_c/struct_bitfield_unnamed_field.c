typedef struct {
    char first: 1;
    char second: 2;
    char : 0;
    char fourth: 1;
} eightbits;

// translate-c
// c_frontend=clang
//
// pub const eightbits = @import("std").zig.c_translation.EmulateBitfieldStruct(struct {
//     first: u1 = @import("std").mem.zeroes(u1),
//     second: u2 = @import("std").mem.zeroes(u2),
//     unnamed_0: void = @import("std").mem.zeroes(void),
//     fourth: u1 = @import("std").mem.zeroes(u1),
// }, &([4]type{
//     u8,
//     u8,
//     u8,
//     u8,
// }), .{});