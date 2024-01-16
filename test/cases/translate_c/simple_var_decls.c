void foo(void) {
    int a;
    char b = 123;
    const int c;
    const unsigned d = 440;
    int e = 10;
    unsigned int f = 10u;
}

// translate-c
// c_frontends=clang
//
// pub export fn foo() void {
//     var a: c_int = undefined;
//     _ = &a;
//     var b: u8 = 123;
//     _ = &b;
//     const c: c_int = undefined;
//     _ = &c;
//     const d: c_uint = 440;
//     _ = &d;
//     var e: c_int = 10;
//     _ = &e;
//     var f: c_uint = 10;
//     _ = &f;
// }
