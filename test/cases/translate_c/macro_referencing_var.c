extern float foo;
#define FOO_TWICE foo * 2.0f
#define FOO_NEGATIVE -foo

#define BAR 10.0f
#define BAR_TWICE BAR * 2.0f

// translate-c
// c_frontend=clang
//
// pub extern var foo: f32;
//
// pub inline fn FOO_TWICE() @TypeOf(foo * @as(f32, 2.0)) {
//     return foo * @as(f32, 2.0);
// }
//
// pub inline fn FOO_NEGATIVE() @TypeOf(-foo) {
//     return -foo;
// }
// pub const BAR = @as(f32, 10.0);
// pub const BAR_TWICE = BAR * @as(f32, 2.0);
