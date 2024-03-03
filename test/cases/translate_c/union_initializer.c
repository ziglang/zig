union { int x; char c[4]; }
  ua = {1},
  ub = {.c={'a','b','b','a'}};

// translate-c
// c_frontend=clang
//
// const union_unnamed_1 = extern union {
//     x: c_int,
//     c: [4]u8,
// };
// pub export var ua: union_unnamed_1 = union_unnamed_1{
//     .x = @as(c_int, 1),
// };
// pub export var ub: union_unnamed_1 = union_unnamed_1{
//     .c = [4]u8{
//         'a',
//         'b',
//         'b',
//         'a',
//     },
// };
