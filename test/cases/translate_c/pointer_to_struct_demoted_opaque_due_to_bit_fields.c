struct Foo {
    unsigned int: 1;
};
struct Bar {
    struct Foo *foo;
};

// translate-c
// c_frontend=clang
//
// pub const struct_Foo = opaque {};
// 
// pub const struct_Bar = extern struct {
//     foo: ?*struct_Foo = @import("std").mem.zeroes(?*struct_Foo),
// };
