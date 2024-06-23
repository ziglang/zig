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
//     a: c_short align(1),
//     b: f32 align(1),
//     c: f64 align(1),
//     x: c_short align(1),
//     y: f32 align(1),
//     z: f64 align(1),
// };
