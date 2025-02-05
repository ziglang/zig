struct Bar;

struct Foo {
    struct Bar *next;
};

struct Bar {
    struct Foo *next;
};

// translate-c
// c_frontend=clang
//
// pub const struct_Bar = extern struct {
//     next: [*c]struct_Foo = @import("std").mem.zeroes([*c]struct_Foo),
// };
// 
// pub const struct_Foo = extern struct {
//     next: [*c]struct_Bar = @import("std").mem.zeroes([*c]struct_Bar),
// };
