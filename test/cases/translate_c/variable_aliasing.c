static long a = 2;
static long b = 2;
static int c = 4;
void foo(char c) {
    int a;
    char b = 123;
    b = (char) a;
    {
        int d = 5;
    }
    unsigned d = 440;
}

// translate-c
// c_frontends=clang
//
// pub var a: c_long = 2;
// pub var b: c_long = 2;
// pub var c: c_int = 4;
// pub export fn foo(arg_c_1: u8) void {
//     var c_1 = arg_c_1;
//     _ = &c_1;
//     var a_2: c_int = undefined;
//     _ = &a_2;
//     var b_3: u8 = 123;
//     _ = &b_3;
//     b_3 = @as(u8, @bitCast(@as(i8, @truncate(a_2))));
//     {
//         var d: c_int = 5;
//         _ = &d;
//     }
//     var d: c_uint = 440;
//     _ = &d;
// }
