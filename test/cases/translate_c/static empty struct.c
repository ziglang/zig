struct empty_struct {};

static inline void foo() {
    static struct empty_struct bar = {};
}

// translate-c
// target=x86_64-linux
// c_frontend=clang
//
// pub const struct_empty_struct = extern struct {};
// pub fn foo() callconv(.C) void {
//     const bar = struct {
//         var static: struct_empty_struct = @import("std").mem.zeroes(struct_empty_struct);
//     };
//     _ = &bar;
// }
