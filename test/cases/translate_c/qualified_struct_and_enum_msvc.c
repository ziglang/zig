struct Foo {
    int x;
    int y;
};
enum Bar {
    BarA,
    BarB,
};
void func(struct Foo *a, enum Bar **b);

// translate-c
// c_frontend=clang
// target=x86_64-windows-msvc
//
// pub const struct_Foo = extern struct {
//     x: c_int = @import("std").mem.zeroes(c_int),
//     y: c_int = @import("std").mem.zeroes(c_int),
// };
// pub const BarA: c_int = 0;
// pub const BarB: c_int = 1;
// pub const enum_Bar = c_int;
// pub extern fn func(a: [*c]struct_Foo, b: [*c][*c]enum_Bar) void;
//
// pub const Foo = struct_Foo;
// pub const Bar = enum_Bar;
