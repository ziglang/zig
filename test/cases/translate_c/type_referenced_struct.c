// When clang uses the <arch>-windows-none, triple it behaves as MSVC and
// interprets the inner `struct Bar` as an anonymous structure
struct Foo {
    struct Bar{
        int b;
    };
    struct Bar c;
};

// translate-c
// c_frontend=aro,clang
// target=x86_64-linux-gnu
//
// pub const struct_Bar_1 = extern struct {
//     b: c_int = @import("std").mem.zeroes(c_int),
// };
// pub const struct_Foo = extern struct {
//     c: struct_Bar_1 = @import("std").mem.zeroes(struct_Bar_1),
// };
