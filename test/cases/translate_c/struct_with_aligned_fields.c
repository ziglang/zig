struct foo {
    __attribute__((aligned(4))) short bar;
};

// translate-c
// c_frontend=clang
// 
// pub const struct_foo = extern struct {
//     bar: c_short align(4) = @import("std").mem.zeroes(c_short),
// };
