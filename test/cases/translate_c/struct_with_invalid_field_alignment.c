// The aligned attribute cannot decrease the alignment of a field. The packed attribute is required 
// for decreasing the alignment. gcc and clang will compile these structs without error 
// (and possibly without warning), but checking the alignment will reveal a different value than 
// what was requested. This is consistent with the gcc documentation on type attributes.
//
// This test is currently broken for the clang frontend. See issue #19307.

struct foo {
  __attribute__((aligned(1)))int x;
};

struct bar {
  __attribute__((aligned(2)))float y;
};

struct baz {
  __attribute__((aligned(4)))double z;
};

// translate-c
// c_frontend=aro
// target=x86_64-linux
//
// pub const struct_foo = extern struct {
//     x: c_int = @import("std").mem.zeroes(c_int),
// };
//
// pub const struct_bar = extern struct {
//     y: f32 = @import("std").mem.zeroes(f32),
// };
//
// pub const struct_baz = extern struct {
//     z: f64 = @import("std").mem.zeroes(f64),
// };
//
