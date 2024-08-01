typedef struct {
    signed int v0;
    unsigned b0: 1;
    unsigned b1: 1;
    unsigned b2: 1;
} word;

// translate-c
// c_frontend=clang
//
// pub const word = @import("std").zig.c_translation.EmulateBitfieldStruct(&(.{ .{
//     .name = "v0",
//     .type = c_int,
//     .backing_integer = null,
// }, .{
//     .name = "b0",
//     .type = u1,
//     .backing_integer = c_uint,
// }, .{
//     .name = "b1",
//     .type = u1,
//     .backing_integer = c_uint,
// }, .{
//     .name = "b2",
//     .type = u1,
//     .backing_integer = c_uint,
// } }), .{});