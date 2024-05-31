extern float number;
#define number_twice number * 2.0f
#define number_negative -number

// translate-c
// c_frontend=clang
//
// pub inline fn number_twice() @TypeOf(number * @as(f32, 2.0)) {
//     return number * @as(f32, 2.0);
// }
//
// pub inline fn number_negative() @TypeOf(-number) {
//     return -number;
// }
