typedef struct {
    char first: 1;
    char second: 2;
    char : 0;
    char fourth: 1;
} eightbits;

// translate-c
// c_frontend=clang
//
// pub const eightbits = @import("std").zig.c_translation.EmulateBitfieldStruct(&(.{ .{
//     .name = "first",
//     .type = u1,
//     .backing_integer = u8,
// }, .{
//     .name = "second",
//     .type = u2,
//     .backing_integer = u8,
// }, .{
//     .name = "unnamed_0",
//     .type = void,
//     .backing_integer = u8,
// }, .{
//     .name = "fourth",
//     .type = u1,
//     .backing_integer = u8,
// } }), .{});