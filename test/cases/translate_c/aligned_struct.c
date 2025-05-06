struct __attribute__((aligned(16))) foo {
    int bar;
    int baz;
};

// translate-c
// c_frontend=aro,clang
//
// pub const struct_foo = extern struct {
//     bar: c_int align(16) = @import("std").mem.zeroes(c_int),
//     baz: c_int = @import("std").mem.zeroes(c_int),
// };
