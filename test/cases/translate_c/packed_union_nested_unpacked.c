// NOTE: The nested struct is *not* packed/aligned,
// even though the parent struct is
// this is consistent with GCC docs
union Foo{
  short x;
  double y;
  struct {
      int b;
  } z;
} __attribute__((packed));

// translate-c
// c_frontend=aro,clang
//
// const struct_unnamed_1 = extern struct {
//     b: c_int = @import("std").mem.zeroes(c_int),
// };
// 
// pub const union_Foo = extern union {
//     x: c_short align(1),
//     y: f64 align(1),
//     z: struct_unnamed_1 align(1),
// };
// 
// pub const Foo = union_Foo;
