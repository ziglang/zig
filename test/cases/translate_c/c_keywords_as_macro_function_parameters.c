#define MACRO_1(int) ((int) + 1)

#define MACRO_2(char) (char + 2)

#define MACRO_3(typedef) (typedef + 3)

#define MACRO_4(return) (return + 4)

#define MACRO_5(alignof) ((alignof) + 5)

#define MACRO_6(signed, x) ((signed) + (x) + 6)

#define MACRO_7(sizeof) ((sizeof) + 7)

// translate-c
// c_frontend=clang
//
// pub inline fn MACRO_1(int: anytype) @TypeOf(int + @as(c_int, 1)) {
//     _ = &int;
//     return int + @as(c_int, 1);
// }
// pub inline fn MACRO_2(char: anytype) @TypeOf(char + @as(c_int, 2)) {
//     _ = &char;
//     return char + @as(c_int, 2);
// }
// pub inline fn MACRO_3(typedef: anytype) @TypeOf(typedef + @as(c_int, 3)) {
//     _ = &typedef;
//     return typedef + @as(c_int, 3);
// }
// pub inline fn MACRO_4(@"return": anytype) @TypeOf(@"return" + @as(c_int, 4)) {
//     _ = &@"return";
//     return @"return" + @as(c_int, 4);
// }
// pub inline fn MACRO_5(alignof: anytype) @TypeOf(alignof + @as(c_int, 5)) {
//     _ = &alignof;
//     return alignof + @as(c_int, 5);
// }
// pub inline fn MACRO_6(signed: anytype, x: anytype) @TypeOf((signed + x) + @as(c_int, 6)) {
//     _ = &signed;
//     _ = &x;
//     return (signed + x) + @as(c_int, 6);
// }
// pub inline fn MACRO_7(sizeof: anytype) @TypeOf(sizeof + @as(c_int, 7)) {
//     _ = &sizeof;
//     return sizeof + @as(c_int, 7);
// }
