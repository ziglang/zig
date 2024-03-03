struct __attribute__((packed)) bar {
  short a;
  float b;
  double c;
  short x;
  float y;
  double z;
};

// translate-c
// c_frontend=aro,clang
//
// pub const struct_bar = extern struct {
//     a: c_short align(1) = @import("std").mem.zeroes(c_short),
//     b: f32 align(1) = @import("std").mem.zeroes(f32),
//     c: f64 align(1) = @import("std").mem.zeroes(f64),
//     x: c_short align(1) = @import("std").mem.zeroes(c_short),
//     y: f32 align(1) = @import("std").mem.zeroes(f32),
//     z: f64 align(1) = @import("std").mem.zeroes(f64),
// };
