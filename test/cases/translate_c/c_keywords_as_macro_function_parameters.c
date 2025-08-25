#define GUARDED_INT_ADDITION(int) ((int) + 1)

#define UNGUARDED_INT_SUBTRACTION(int) (int - 2)

#define GUARDED_INT_MULTIPLY(int) ((int) * 3)

#define UNGUARDED_INT_DIVIDE(int) (int / 4)

#define WRAPPED_RETURN(return) ((return) % 2)

#define UNWRAPPED_RETURN(return) (return ^ 0x7F)

#define WITH_TWO_PARAMETERS(signed, x) ((signed) + (x) + 9)

#define GUARDED_ALIGNOF(_Alignof) ((_Alignof) & 0x55)

#define UNGUARDED_ALIGNOF(_Alignof) (_Alignof | 0x80)

#define GUARDED_SIZEOF(sizeof) ((sizeof) == 64)

#define UNGUARDED_SIZEOF(sizeof) (sizeof < 64)

#define SIZEOF(x) ((int)sizeof(x))

#define SIZEOF2(x) ((int)sizeof x)

// translate-c
// c_frontend=clang
//
// pub inline fn GUARDED_INT_ADDITION(int: anytype) @TypeOf(int + @as(c_int, 1)) {
//     _ = &int;
//     return int + @as(c_int, 1);
// }
// pub inline fn UNGUARDED_INT_SUBTRACTION(int: anytype) @TypeOf(int - @as(c_int, 2)) {
//     _ = &int;
//     return int - @as(c_int, 2);
// }
// pub inline fn GUARDED_INT_MULTIPLY(int: anytype) @TypeOf(int * @as(c_int, 3)) {
//     _ = &int;
//     return int * @as(c_int, 3);
// }
// pub inline fn UNGUARDED_INT_DIVIDE(int: anytype) @TypeOf(@import("std").zig.c_translation.MacroArithmetic.div(int, @as(c_int, 4))) {
//     _ = &int;
//     return @import("std").zig.c_translation.MacroArithmetic.div(int, @as(c_int, 4));
// }
// pub inline fn WRAPPED_RETURN(@"return": anytype) @TypeOf(@import("std").zig.c_translation.MacroArithmetic.rem(@"return", @as(c_int, 2))) {
//     _ = &@"return";
//     return @import("std").zig.c_translation.MacroArithmetic.rem(@"return", @as(c_int, 2));
// }
// pub inline fn UNWRAPPED_RETURN(@"return": anytype) @TypeOf(@"return" ^ @as(c_int, 0x7F)) {
//     _ = &@"return";
//     return @"return" ^ @as(c_int, 0x7F);
// }
// pub inline fn WITH_TWO_PARAMETERS(signed: anytype, x: anytype) @TypeOf((signed + x) + @as(c_int, 9)) {
//     _ = &signed;
//     _ = &x;
//     return (signed + x) + @as(c_int, 9);
// }
// pub inline fn GUARDED_ALIGNOF(_Alignof: anytype) @TypeOf(_Alignof & @as(c_int, 0x55)) {
//     _ = &_Alignof;
//     return _Alignof & @as(c_int, 0x55);
// }
// pub inline fn UNGUARDED_ALIGNOF(_Alignof: anytype) @TypeOf(_Alignof | @as(c_int, 0x80)) {
//     _ = &_Alignof;
//     return _Alignof | @as(c_int, 0x80);
// }
// pub inline fn GUARDED_SIZEOF(sizeof: anytype) @TypeOf(sizeof == @as(c_int, 64)) {
//     _ = &sizeof;
//     return sizeof == @as(c_int, 64);
// }
// pub inline fn UNGUARDED_SIZEOF(sizeof: anytype) @TypeOf(sizeof < @as(c_int, 64)) {
//     _ = &sizeof;
//     return sizeof < @as(c_int, 64);
// }
// pub inline fn SIZEOF(x: anytype) c_int {
//     _ = &x;
//     return @import("std").zig.c_translation.cast(c_int, @import("std").zig.c_translation.sizeof(x));
// }
// pub inline fn SIZEOF2(x: anytype) c_int {
//     _ = &x;
//     return @import("std").zig.c_translation.cast(c_int, @import("std").zig.c_translation.sizeof(x));
// }
