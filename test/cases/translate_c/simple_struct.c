struct Foo {
    int x;
};

// translate-c
// c_frontend=aro,clang
//
// const struct_Foo = extern struct {
//     x: c_int = @import("std").mem.zeroes(c_int),
// };
// 
// pub const Foo = struct_Foo;
