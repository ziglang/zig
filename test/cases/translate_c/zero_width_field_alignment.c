struct __attribute__((packed)) foo {
  int x;
  struct {};
  float y;
  union {};
};

// translate-c
// c_frontend=aro
//
// const struct_unnamed_1 = extern struct {};
// const union_unnamed_2 = extern union {};
// pub const struct_foo = extern struct {
//     x: c_int align(1) = @import("std").mem.zeroes(c_int),
//     unnamed_0: struct_unnamed_1 align(1) = @import("std").mem.zeroes(struct_unnamed_1),
//     y: f32 align(1) = @import("std").mem.zeroes(f32),
//     unnamed_1: union_unnamed_2 align(1) = @import("std").mem.zeroes(union_unnamed_2),
// };
