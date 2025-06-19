typedef int i32x2 __attribute__((__vector_size__(8)));
typedef float f32x2 __attribute__((__vector_size__(8)));

f32x2 cast_function(i32x2 x) {
  return (f32x2) __builtin_convertvector((i32x2) { x[0], x[1] }, f32x2);
}

// translate-c
// c_frontend=clang
//
// pub export fn cast_function(arg_x: i32x2) f32x2 {
//     var x = arg_x;
//     _ = &x;
//     return blk: {
//         const tmp = blk_1: {
//             const tmp_2 = x[@as(c_uint, @intCast(@as(c_int, 0)))];
//             const tmp_3 = x[@as(c_uint, @intCast(@as(c_int, 1)))];
//             break :blk_1 i32x2{
//                 tmp_2,
//                 tmp_3,
//             };
//         };
//         const tmp_1 = @as(f32, @floatFromInt(tmp[0]));
//         const tmp_2 = @as(f32, @floatFromInt(tmp[1]));
//         break :blk f32x2{
//             tmp_1,
//             tmp_2,
//         };
//     };
// }
