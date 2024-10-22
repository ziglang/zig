typedef struct word word;

struct word {
    signed int (*ptr)(word *v);
    unsigned first: 1;
};

// translate-c
// c_frontend=clang
//
// pub const struct_word = @import("std").zig.c_translation.EmulateBitfieldStruct(&(.{ .{
//     .name = "ptr",
//     .type = ?*const fn (?*word) callconv(.C) c_int,
//     .backing_integer = null,
//     .is_pointer = true,
// }, .{
//     .name = "first",
//     .type = u1,
//     .backing_integer = c_uint,
// } }), .{});