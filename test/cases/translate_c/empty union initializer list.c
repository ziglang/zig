union U {
    int x;
    long y;
};

void foo(void) {
    union U u = {};
}
// translate-c
// target=x86_64-linux
// c_frontend=clang
//
// pub const union_U = extern union {
//     x: c_int,
//     y: c_long,
// };
// pub export fn foo() void {
//     var u: union_U = @import("std").mem.zeroes(union_U);
//     _ = &u;
// }
