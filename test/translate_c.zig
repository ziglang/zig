const tests = @import("tests.zig");
const builtin = @import("builtin");

// add_both - test for stage1 and stage2, in #include mode
// add - test stage1 only, in #include mode
// add_2 - test stage2 only
// addC_both - test for stage1 and stage2, in -c mode
// addC - test stage1 only, in -c mode

pub fn addCases(cases: *tests.TranslateCContext) void {
    /////////////// Cases that pass for both stage1/stage2 ////////////////
    cases.add_both("simple function prototypes",
        \\void __attribute__((noreturn)) foo(void);
        \\int bar(void);
    , &[_][]const u8{
        \\pub extern fn foo() noreturn;
        \\pub extern fn bar() c_int;
    });

    cases.addC_both("simple var decls",
        \\void foo(void) {
        \\    int a;
        \\    char b = 123;
        \\    const int c;
        \\    const unsigned d = 440;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    var b: u8 = @as(u8, 123);
        \\    const c: c_int = undefined;
        \\    const d: c_uint = @as(c_uint, 440);
        \\}
    });

    cases.addC_both("ignore result, explicit function arguments",
        \\void foo(void) {
        \\    int a;
        \\    1;
        \\    "hey";
        \\    1 + 1;
        \\    1 - 1;
        \\    a = 1;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    _ = 1;
        \\    _ = "hey";
        \\    _ = (1 + 1);
        \\    _ = (1 - 1);
        \\    a = 1;
        \\}
    });

    cases.addC_both("variables",
        \\extern int extern_var;
        \\static const int int_var = 13;
    , &[_][]const u8{
        \\pub extern var extern_var: c_int;
    ,
        \\pub const int_var: c_int = 13;
    });

    cases.add_both("const ptr initializer",
        \\static const char *v0 = "0.0.0";
    , &[_][]const u8{
        \\pub var v0: [*c]const u8 = "0.0.0";
    });

    cases.addC_both("static incomplete array inside function",
        \\void foo(void) {
        \\    static const char v2[] = "2.2.2";
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    const v2: [*c]const u8 = "2.2.2";
        \\}
    });

    cases.addC_both("simple function definition",
        \\void foo(void) {}
        \\static void bar(void) {}
    , &[_][]const u8{
        \\pub export fn foo() void {}
        \\pub fn bar() void {}
    });

    cases.add_both("typedef void",
        \\typedef void Foo;
        \\Foo fun(Foo *a);
    , &[_][]const u8{
        \\pub const Foo = c_void;
    ,
        \\pub extern fn fun(a: ?*Foo) Foo;
    });

    cases.add_both("duplicate typedef",
        \\typedef long foo;
        \\typedef int bar;
        \\typedef long foo;
        \\typedef int baz;
    , &[_][]const u8{
        \\pub const foo = c_long;
        \\pub const bar = c_int;
        \\pub const baz = c_int;
    });

    cases.addC_both("casting pointers to ints and ints to pointers",
        \\void foo(void);
        \\void bar(void) {
        \\    void *func_ptr = foo;
        \\    void (*typed_func_ptr)(void) = (void (*)(void)) (unsigned long) func_ptr;
        \\}
    , &[_][]const u8{
        \\pub extern fn foo() void;
        \\pub export fn bar() void {
        \\    var func_ptr: ?*c_void = @ptrCast(?*c_void, foo);
        \\    var typed_func_ptr: ?extern fn () void = @intToPtr(?extern fn () void, @as(c_ulong, @ptrToInt(func_ptr)));
        \\}
    });

    cases.add_both("noreturn attribute",
        \\void foo(void) __attribute__((noreturn));
    , &[_][]const u8{
        \\pub extern fn foo() noreturn;
    });

    cases.addC_both("add, sub, mul, div, rem",
        \\int s() {
        \\    int a, b, c;
        \\    c = a + b;
        \\    c = a - b;
        \\    c = a * b;
        \\    c = a / b;
        \\    c = a % b;
        \\}
        \\unsigned u() {
        \\    unsigned a, b, c;
        \\    c = a + b;
        \\    c = a - b;
        \\    c = a * b;
        \\    c = a / b;
        \\    c = a % b;
        \\}
    , &[_][]const u8{
        \\pub export fn s() c_int {
        \\    var a: c_int = undefined;
        \\    var b: c_int = undefined;
        \\    var c: c_int = undefined;
        \\    c = (a + b);
        \\    c = (a - b);
        \\    c = (a * b);
        \\    c = @divTrunc(a, b);
        \\    c = @rem(a, b);
        \\}
        \\pub export fn u() c_uint {
        \\    var a: c_uint = undefined;
        \\    var b: c_uint = undefined;
        \\    var c: c_uint = undefined;
        \\    c = (a +% b);
        \\    c = (a -% b);
        \\    c = (a *% b);
        \\    c = (a / b);
        \\    c = (a % b);
        \\}
    });

    cases.add_both("typedef of function in struct field",
        \\typedef void lws_callback_function(void);
        \\struct Foo {
        \\    void (*func)(void);
        \\    lws_callback_function *callback_http;
        \\};
    , &[_][]const u8{
        \\pub const lws_callback_function = extern fn () void;
        \\pub const struct_Foo = extern struct {
        \\    func: ?extern fn () void,
        \\    callback_http: ?lws_callback_function,
        \\};
    });

    cases.add_both("pointer to struct demoted to opaque due to bit fields",
        \\struct Foo {
        \\    unsigned int: 1;
        \\};
        \\struct Bar {
        \\    struct Foo *foo;
        \\};
    , &[_][]const u8{
        \\pub const struct_Foo = @OpaqueType();
    ,
        \\pub const struct_Bar = extern struct {
        \\    foo: ?*struct_Foo,
        \\};
    });

    cases.add_both("macro with left shift",
        \\#define REDISMODULE_READ (1<<0)
    , &[_][]const u8{
        \\pub const REDISMODULE_READ = 1 << 0;
    });

    cases.add_both("double define struct",
        \\typedef struct Bar Bar;
        \\typedef struct Foo Foo;
        \\
        \\struct Foo {
        \\    Foo *a;
        \\};
        \\
        \\struct Bar {
        \\    Foo *a;
        \\};
    , &[_][]const u8{
        \\pub const struct_Foo = extern struct {
        \\    a: [*c]Foo,
        \\};
    ,
        \\pub const Foo = struct_Foo;
    ,
        \\pub const struct_Bar = extern struct {
        \\    a: [*c]Foo,
        \\};
    ,
        \\pub const Bar = struct_Bar;
    });

    cases.add_both("simple struct",
        \\struct Foo {
        \\    int x;
        \\    char *y;
        \\};
    , &[_][]const u8{
        \\const struct_Foo = extern struct {
        \\    x: c_int,
        \\    y: [*c]u8,
        \\};
    ,
        \\pub const Foo = struct_Foo;
    });

    cases.add_both("self referential struct with function pointer",
        \\struct Foo {
        \\    void (*derp)(struct Foo *foo);
        \\};
    , &[_][]const u8{
        \\pub const struct_Foo = extern struct {
        \\    derp: ?extern fn ([*c]struct_Foo) void,
        \\};
    ,
        \\pub const Foo = struct_Foo;
    });

    cases.add_both("struct prototype used in func",
        \\struct Foo;
        \\struct Foo *some_func(struct Foo *foo, int x);
    , &[_][]const u8{
        \\pub const struct_Foo = @OpaqueType();
    ,
        \\pub extern fn some_func(foo: ?*struct_Foo, x: c_int) ?*struct_Foo;
    ,
        \\pub const Foo = struct_Foo;
    });

    cases.add_both("#define an unsigned integer literal",
        \\#define CHANNEL_COUNT 24
    , &[_][]const u8{
        \\pub const CHANNEL_COUNT = 24;
    });

    cases.add_both("#define referencing another #define",
        \\#define THING2 THING1
        \\#define THING1 1234
    , &[_][]const u8{
        \\pub const THING1 = 1234;
    ,
        \\pub const THING2 = THING1;
    });

    cases.add_both("circular struct definitions",
        \\struct Bar;
        \\
        \\struct Foo {
        \\    struct Bar *next;
        \\};
        \\
        \\struct Bar {
        \\    struct Foo *next;
        \\};
    , &[_][]const u8{
        \\pub const struct_Bar = extern struct {
        \\    next: [*c]struct_Foo,
        \\};
    ,
        \\pub const struct_Foo = extern struct {
        \\    next: [*c]struct_Bar,
        \\};
    });

    cases.add_both("#define string",
        \\#define  foo  "a string"
    , &[_][]const u8{
        \\pub const foo = "a string";
    });

    cases.add_both("zig keywords in C code",
        \\struct comptime {
        \\    int defer;
        \\};
    , &[_][]const u8{
        \\pub const struct_comptime = extern struct {
        \\    @"defer": c_int,
        \\};
    ,
        \\pub const @"comptime" = struct_comptime;
    });

    cases.add_both("macro with parens around negative number",
        \\#define LUA_GLOBALSINDEX        (-10002)
    , &[_][]const u8{
        \\pub const LUA_GLOBALSINDEX = -10002;
    });

    cases.add_both(
        "u integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0U",
        &[_][]const u8{
            "pub const ZERO = @as(c_uint, 0);",
        },
    );

    cases.add_both(
        "l integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0L",
        &[_][]const u8{
            "pub const ZERO = @as(c_long, 0);",
        },
    );

    cases.add_both(
        "ul integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0UL",
        &[_][]const u8{
            "pub const ZERO = @as(c_ulong, 0);",
        },
    );

    cases.add_both(
        "lu integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0LU",
        &[_][]const u8{
            "pub const ZERO = @as(c_ulong, 0);",
        },
    );

    cases.add_both(
        "ll integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0LL",
        &[_][]const u8{
            "pub const ZERO = @as(c_longlong, 0);",
        },
    );

    cases.add_both(
        "ull integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0ULL",
        &[_][]const u8{
            "pub const ZERO = @as(c_ulonglong, 0);",
        },
    );

    cases.add_both(
        "llu integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0LLU",
        &[_][]const u8{
            "pub const ZERO = @as(c_ulonglong, 0);",
        },
    );

    cases.add_both(
        "bitwise not on u-suffixed 0 (zero) in macro definition",
        "#define NOT_ZERO (~0U)",
        &[_][]const u8{
            "pub const NOT_ZERO = ~@as(c_uint, 0);",
        },
    );

    cases.addC_both("null statements",
        \\void foo(void) {
        \\    ;;;;;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    {}
        \\    {}
        \\    {}
        \\    {}
        \\    {}
        \\}
    });

    if (builtin.os != builtin.Os.windows) {
        // Windows treats this as an enum with type c_int
        cases.add_both("big negative enum init values when C ABI supports long long enums",
            \\enum EnumWithInits {
            \\    VAL01 = 0,
            \\    VAL02 = 1,
            \\    VAL03 = 2,
            \\    VAL04 = 3,
            \\    VAL05 = -1,
            \\    VAL06 = -2,
            \\    VAL07 = -3,
            \\    VAL08 = -4,
            \\    VAL09 = VAL02 + VAL08,
            \\    VAL10 = -1000012000,
            \\    VAL11 = -1000161000,
            \\    VAL12 = -1000174001,
            \\    VAL13 = VAL09,
            \\    VAL14 = VAL10,
            \\    VAL15 = VAL11,
            \\    VAL16 = VAL13,
            \\    VAL17 = (VAL16 - VAL10 + 1),
            \\    VAL18 = 0x1000000000000000L,
            \\    VAL19 = VAL18 + VAL18 + VAL18 - 1,
            \\    VAL20 = VAL19 + VAL19,
            \\    VAL21 = VAL20 + 0xFFFFFFFFFFFFFFFF,
            \\    VAL22 = 0xFFFFFFFFFFFFFFFF + 1,
            \\    VAL23 = 0xFFFFFFFFFFFFFFFF,
            \\};
        , &[_][]const u8{
            \\pub const enum_EnumWithInits = extern enum(c_longlong) {
            \\    VAL01 = 0,
            \\    VAL02 = 1,
            \\    VAL03 = 2,
            \\    VAL04 = 3,
            \\    VAL05 = -1,
            \\    VAL06 = -2,
            \\    VAL07 = -3,
            \\    VAL08 = -4,
            \\    VAL09 = -3,
            \\    VAL10 = -1000012000,
            \\    VAL11 = -1000161000,
            \\    VAL12 = -1000174001,
            \\    VAL13 = -3,
            \\    VAL14 = -1000012000,
            \\    VAL15 = -1000161000,
            \\    VAL16 = -3,
            \\    VAL17 = 1000011998,
            \\    VAL18 = 1152921504606846976,
            \\    VAL19 = 3458764513820540927,
            \\    VAL20 = 6917529027641081854,
            \\    VAL21 = 6917529027641081853,
            \\    VAL22 = 0,
            \\    VAL23 = -1,
            \\};
        });
    }

    cases.addC_both("predefined expressions",
        \\void foo(void) {
        \\    __func__;
        \\    __FUNCTION__;
        \\    __PRETTY_FUNCTION__;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    _ = "foo";
        \\    _ = "foo";
        \\    _ = "void foo(void)";
        \\}
    });

    cases.addC_both("ignore result, no function arguments",
        \\void foo() {
        \\    int a;
        \\    1;
        \\    "hey";
        \\    1 + 1;
        \\    1 - 1;
        \\    a = 1;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    _ = 1;
        \\    _ = "hey";
        \\    _ = (1 + 1);
        \\    _ = (1 - 1);
        \\    a = 1;
        \\}
    });

    cases.add_both("constant size array",
        \\void func(int array[20]);
    , &[_][]const u8{
        \\pub extern fn func(array: [*c]c_int) void;
    });

    cases.add_both("__cdecl doesn't mess up function pointers",
        \\void foo(void (__cdecl *fn_ptr)(void));
    , &[_][]const u8{
        \\pub extern fn foo(fn_ptr: ?extern fn () void) void;
    });

    cases.addC_both("void cast",
        \\void foo() {
        \\    int a;
        \\    (void) a;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    _ = a;
        \\}
    });

    cases.addC_both("implicit cast to void *",
        \\void *foo() {
        \\    unsigned short *x;
        \\    return x;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() ?*c_void {
        \\    var x: [*c]c_ushort = undefined;
        \\    return @ptrCast(?*c_void, x);
        \\}
    });

    cases.addC_both("null pointer implicit cast",
        \\int* foo(void) {
        \\    return 0;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() [*c]c_int {
        \\    return null;
        \\}
    });

    cases.add_both("simple union",
        \\union Foo {
        \\    int x;
        \\    double y;
        \\};
    , &[_][]const u8{
        \\pub const union_Foo = extern union {
        \\    x: c_int,
        \\    y: f64,
        \\};
    ,
        \\pub const Foo = union_Foo;
    });

    cases.addC_both("string literal",
        \\const char *foo(void) {
        \\    return "bar";
        \\}
    , &[_][]const u8{
        \\pub export fn foo() [*c]const u8 {
        \\    return "bar";
        \\}
    });

    cases.addC_both("return void",
        \\void foo(void) {
        \\    return;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    return;
        \\}
    });

    cases.addC_both("for loop",
        \\void foo(void) {
        \\    for (int i = 0; i; i = i + 1) { }
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    {
        \\        var i: c_int = 0;
        \\        while (i != 0) : (i = (i + 1)) {}
        \\    }
        \\}
    });

    cases.addC_both("empty for loop",
        \\void foo(void) {
        \\    for (;;) { }
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    while (true) {}
        \\}
    });

    cases.addC_both("break statement",
        \\void foo(void) {
        \\    for (;;) {
        \\        break;
        \\    }
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    while (true) {
        \\        break;
        \\    }
        \\}
    });

    cases.addC_both("continue statement",
        \\void foo(void) {
        \\    for (;;) {
        \\        continue;
        \\    }
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    while (true) {
        \\        continue;
        \\    }
        \\}
    });

    cases.addC_both("pointer casting",
        \\float *ptrcast() {
        \\    int *a;
        \\    return (float *)a;
        \\}
    , &[_][]const u8{
        \\pub export fn ptrcast() [*c]f32 {
        \\    var a: [*c]c_int = undefined;
        \\    return @ptrCast([*c]f32, @alignCast(@alignOf(f32), a));
        \\}
    });

    cases.addC_both("pointer conversion with different alignment",
        \\void test_ptr_cast() {
        \\    void *p;
        \\    {
        \\        char *to_char = (char *)p;
        \\        short *to_short = (short *)p;
        \\        int *to_int = (int *)p;
        \\        long long *to_longlong = (long long *)p;
        \\    }
        \\    {
        \\        char *to_char = p;
        \\        short *to_short = p;
        \\        int *to_int = p;
        \\        long long *to_longlong = p;
        \\    }
        \\}
    , &[_][]const u8{
        \\pub export fn test_ptr_cast() void {
        \\    var p: ?*c_void = undefined;
        \\    {
        \\        var to_char: [*c]u8 = @ptrCast([*c]u8, @alignCast(@alignOf(u8), p));
        \\        var to_short: [*c]c_short = @ptrCast([*c]c_short, @alignCast(@alignOf(c_short), p));
        \\        var to_int: [*c]c_int = @ptrCast([*c]c_int, @alignCast(@alignOf(c_int), p));
        \\        var to_longlong: [*c]c_longlong = @ptrCast([*c]c_longlong, @alignCast(@alignOf(c_longlong), p));
        \\    }
        \\    {
        \\        var to_char: [*c]u8 = @ptrCast([*c]u8, @alignCast(@alignOf(u8), p));
        \\        var to_short: [*c]c_short = @ptrCast([*c]c_short, @alignCast(@alignOf(c_short), p));
        \\        var to_int: [*c]c_int = @ptrCast([*c]c_int, @alignCast(@alignOf(c_int), p));
        \\        var to_longlong: [*c]c_longlong = @ptrCast([*c]c_longlong, @alignCast(@alignOf(c_longlong), p));
        \\    }
        \\}
    });

    cases.addC_both("while on non-bool",
        \\int while_none_bool() {
        \\    int a;
        \\    float b;
        \\    void *c;
        \\    while (a) return 0;
        \\    while (b) return 1;
        \\    while (c) return 2;
        \\    return 3;
        \\}
    , &[_][]const u8{
        \\pub export fn while_none_bool() c_int {
        \\    var a: c_int = undefined;
        \\    var b: f32 = undefined;
        \\    var c: ?*c_void = undefined;
        \\    while (a != 0) return 0;
        \\    while (b != 0) return 1;
        \\    while (c != null) return 2;
        \\    return 3;
        \\}
    });

    cases.addC_both("for on non-bool",
        \\int for_none_bool() {
        \\    int a;
        \\    float b;
        \\    void *c;
        \\    for (;a;) return 0;
        \\    for (;b;) return 1;
        \\    for (;c;) return 2;
        \\    return 3;
        \\}
    , &[_][]const u8{
        \\pub export fn for_none_bool() c_int {
        \\    var a: c_int = undefined;
        \\    var b: f32 = undefined;
        \\    var c: ?*c_void = undefined;
        \\    while (a != 0) return 0;
        \\    while (b != 0) return 1;
        \\    while (c != null) return 2;
        \\    return 3;
        \\}
    });

    cases.addC_both("bitshift",
        \\int foo(void) {
        \\    return (1 << 2) >> 1;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return (1 << @as(@import("std").math.Log2Int(c_int), 2)) >> @as(@import("std").math.Log2Int(c_int), 1);
        \\}
    });

    cases.addC_both("sizeof",
        \\#include <stddef.h>
        \\size_t size_of(void) {
        \\        return sizeof(int);
        \\}
    , &[_][]const u8{
        \\pub export fn size_of() usize {
        \\    return @sizeOf(c_int);
        \\}
    });

    cases.addC_both("normal deref",
        \\void foo() {
        \\    int *x;
        \\    *x = 1;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var x: [*c]c_int = undefined;
        \\    x.?.* = 1;
        \\}
    });

    cases.addC_both("address of operator",
        \\int foo(void) {
        \\    int x = 1234;
        \\    int *ptr = &x;
        \\    return *ptr;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    var x: c_int = 1234;
        \\    var ptr: [*c]c_int = &x;
        \\    return ptr.?.*;
        \\}
    });

    cases.addC_both("bin not",
        \\int foo() {
        \\    int x;
        \\    return ~x;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    var x: c_int = undefined;
        \\    return ~x;
        \\}
    });

    cases.addC_both("bool not",
        \\int foo() {
        \\    int a;
        \\    float b;
        \\    void *c;
        \\    return !(a == 0);
        \\    return !a;
        \\    return !b;
        \\    return !c;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    var a: c_int = undefined;
        \\    var b: f32 = undefined;
        \\    var c: ?*c_void = undefined;
        \\    return !(a == 0);
        \\    return !(a != 0);
        \\    return !(b != 0);
        \\    return !(c != null);
        \\}
    });

    cases.addC("__extension__ cast",
        \\int foo(void) {
        \\    return __extension__ 1;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return 1;
        \\}
    });

    if (builtin.os != builtin.Os.windows) {
        // sysv_abi not currently supported on windows
        cases.add_both("Macro qualified functions",
            \\void __attribute__((sysv_abi)) foo(void);
        , &[_][]const u8{
            \\pub extern fn foo() void;
        });
    }

    /////////////// Cases that pass for only stage2 ////////////////

    cases.add_2("Parameterless function prototypes",
        \\void a() {}
        \\void b(void) {}
        \\void c();
        \\void d(void);
    , &[_][]const u8{
        \\pub export fn a() void {}
        \\pub export fn b() void {}
        \\pub extern fn c(...) void;
        \\pub extern fn d() void;
    });

    cases.add_2("variable declarations",
        \\extern char arr0[] = "hello";
        \\static char arr1[] = "hello";
        \\char arr2[] = "hello";
    , &[_][]const u8{
        \\pub extern var arr0: [*c]u8 = "hello";
        \\pub var arr1: [*c]u8 = "hello";
        \\pub export var arr2: [*c]u8 = "hello";
    });

    cases.add_2("array initializer expr",
        \\static void foo(void){
        \\    char arr[10] ={1};
        \\    char *arr1[10] ={0};
        \\}
    , &[_][]const u8{
        \\pub fn foo() void {
        \\    var arr: [10]u8 = .{
        \\        @as(u8, 1),
        \\    } ++ .{0} ** 9;
        \\    var arr1: [10][*c]u8 = .{
        \\        null,
        \\    } ++ .{null} ** 9;
        \\}
    });

    cases.add_2("enums",
        \\typedef enum {
        \\    a,
        \\    b,
        \\    c,
        \\} d;
        \\enum {
        \\    e,
        \\    f = 4,
        \\    g,
        \\} h = e;
        \\struct Baz {
        \\    enum {
        \\        i,
        \\        j,
        \\        k,
        \\    } l;
        \\    d m;
        \\};
        \\enum i {
        \\    n,
        \\    o,
        \\    p,
        \\};
    , &[_][]const u8{
        \\pub const a = 0;
        \\pub const b = 1;
        \\pub const c = 2;
        \\const enum_unnamed_1 = extern enum {
        \\    a,
        \\    b,
        \\    c,
        \\};
        \\pub const d = enum_unnamed_1;
        \\pub const e = 0;
        \\pub const f = 4;
        \\pub const g = 5;
        \\const enum_unnamed_2 = extern enum {
        \\    e = 0,
        \\    f = 4,
        \\    g = 5,
        \\};
        \\pub export var h: enum_unnamed_2 = @intToEnum(enum_unnamed_2, e);
        \\pub const i = 0;
        \\pub const j = 1;
        \\pub const k = 2;
        \\const enum_unnamed_3 = extern enum {
        \\    i,
        \\    j,
        \\    k,
        \\};
        \\pub const struct_Baz = extern struct {
        \\    l: enum_unnamed_3,
        \\    m: d,
        \\};
        \\pub const n = 0;
        \\pub const o = 1;
        \\pub const p = 2;
        \\pub const enum_i = extern enum {
        \\    n,
        \\    o,
        \\    p,
        \\};
    ,
        \\pub const Baz = struct_Baz;
    });

    cases.add_2("#define a char literal",
        \\#define A_CHAR  'a'
    , &[_][]const u8{
        \\pub const A_CHAR = 'a';
    });

    cases.add_2("comment after integer literal",
        \\#define SDL_INIT_VIDEO 0x00000020  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = 0x00000020;
    });

    cases.add_2("u integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020u  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_uint, 0x00000020);
    });

    cases.add_2("l integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020l  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_long, 0x00000020);
    });

    cases.add_2("ul integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ul  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulong, 0x00000020);
    });

    cases.add_2("lu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020lu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulong, 0x00000020);
    });

    cases.add_2("ll integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ll  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_longlong, 0x00000020);
    });

    cases.add_2("ull integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ull  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulonglong, 0x00000020);
    });

    cases.add_2("llu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020llu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulonglong, 0x00000020);
    });

    cases.add_2("generate inline func for #define global extern fn",
        \\extern void (*fn_ptr)(void);
        \\#define foo fn_ptr
        \\
        \\extern char (*fn_ptr2)(int, float);
        \\#define bar fn_ptr2
    , &[_][]const u8{
        \\pub extern var fn_ptr: ?extern fn () void;
    ,
        \\pub inline fn foo() void {
        \\    return fn_ptr.?();
        \\}
    ,
        \\pub extern var fn_ptr2: ?extern fn (c_int, f32) u8;
    ,
        \\pub inline fn bar(arg_1: c_int, arg_2: f32) u8 {
        \\    return fn_ptr2.?(arg_1, arg_2);
        \\}
    });

    cases.add_2("macros with field targets",
        \\typedef unsigned int GLbitfield;
        \\typedef void (*PFNGLCLEARPROC) (GLbitfield mask);
        \\typedef void(*OpenGLProc)(void);
        \\union OpenGLProcs {
        \\    OpenGLProc ptr[1];
        \\    struct {
        \\        PFNGLCLEARPROC Clear;
        \\    } gl;
        \\};
        \\extern union OpenGLProcs glProcs;
        \\#define glClearUnion glProcs.gl.Clear
        \\#define glClearPFN PFNGLCLEARPROC
    , &[_][]const u8{
        \\pub const GLbitfield = c_uint;
        \\pub const PFNGLCLEARPROC = ?extern fn (GLbitfield) void;
        \\pub const OpenGLProc = ?extern fn () void;
        \\const struct_unnamed_1 = extern struct {
        \\    Clear: PFNGLCLEARPROC,
        \\};
        \\pub const union_OpenGLProcs = extern union {
        \\    ptr: [1]OpenGLProc,
        \\    gl: struct_unnamed_1,
        \\};
        \\pub extern var glProcs: union_OpenGLProcs;
    ,
        \\pub const glClearPFN = PFNGLCLEARPROC;
    ,
        \\pub inline fn glClearUnion(arg_2: GLbitfield) void {
        \\    return glProcs.gl.Clear.?(arg_2);
        \\}
        ,
        \\pub const OpenGLProcs = union_OpenGLProcs;
    });

    cases.add_2("macro pointer cast",
        \\#define NRF_GPIO ((NRF_GPIO_Type *) NRF_GPIO_BASE)
    , &[_][]const u8{
        \\pub const NRF_GPIO = if (@typeId(@TypeOf(NRF_GPIO_BASE)) == .Pointer) @ptrCast([*c]NRF_GPIO_Type, NRF_GPIO_BASE) else if (@typeId(@TypeOf(NRF_GPIO_BASE)) == .Int) @intToPtr([*c]NRF_GPIO_Type, NRF_GPIO_BASE) else @as([*c]NRF_GPIO_Type, NRF_GPIO_BASE);
    });

    cases.add_2("basic macro function",
        \\extern int c;
        \\#define BASIC(c) (c*2)
    , &[_][]const u8{
        \\pub extern var c: c_int;
    ,
        \\pub inline fn BASIC(c_1: var) @TypeOf(c_1 * 2) {
        \\    return c_1 * 2;
        \\}
    });

    cases.add_2("macro defines string literal with hex",
        \\#define FOO "aoeu\xab derp"
        \\#define FOO2 "aoeu\x0007a derp"
        \\#define FOO_CHAR '\xfF'
    , &[_][]const u8{
        \\pub const FOO = "aoeu\xab derp";
    ,
        \\pub const FOO2 = "aoeu\x7a derp";
    ,
        \\pub const FOO_CHAR = '\xff';
    });

    cases.add_2("variable aliasing",
        \\static long a = 2;
        \\static long b = 2;
        \\static int c = 4;
        \\void foo(char c) {
        \\    int a;
        \\    char b = 123;
        \\    b = (char) a;
        \\    {
        \\        int d = 5;
        \\    }
        \\    unsigned d = 440;
        \\}
    , &[_][]const u8{
        \\pub var a: c_long = @as(c_long, 2);
        \\pub var b: c_long = @as(c_long, 2);
        \\pub var c: c_int = 4;
        \\pub export fn foo(_arg_c_1: u8) void {
        \\    var c_1 = _arg_c_1;
        \\    var a_2: c_int = undefined;
        \\    var b_3: u8 = @as(u8, 123);
        \\    b_3 = @as(u8, a_2);
        \\    {
        \\        var d: c_int = 5;
        \\    }
        \\    var d: c_uint = @as(c_uint, 440);
        \\}
    });

    cases.add_2("comma operator",
        \\int foo(char c) {
        \\    2, 4;
        \\    return 2, 4, 6;
        \\}
    , &[_][]const u8{
        \\pub export fn foo(_arg_c: u8) c_int {
        \\    var c = _arg_c;
        \\    _ = 2;
        \\    _ = 4;
        \\    _ = 2;
        \\    _ = 4;
        \\    return 6;
        \\}
    });

    cases.add_2("wors-case assign",
        \\int foo(char c) {
        \\    int a;
        \\    int b;
        \\    a = b = 2;
        \\}
    , &[_][]const u8{
        \\pub export fn foo(_arg_c: u8) c_int {
        \\    var c = _arg_c;
        \\    var a: c_int = undefined;
        \\    var b: c_int = undefined;
        \\    a = blk: {
        \\        const _tmp_1 = 2;
        \\        b = _tmp_1;
        \\        break :blk _tmp_1;
        \\    };
        \\}
    });

    cases.add_2("if statements",
        \\int foo(char c) {
        \\    if (2) {
        \\        int a = 2;
        \\    }
        \\    if (2, 5) {
        \\        int a = 2;
        \\    }
        \\}
    , &[_][]const u8{
        \\pub export fn foo(_arg_c: u8) c_int {
        \\    var c = _arg_c;
        \\    if (2 != 0) {
        \\        var a: c_int = 2;
        \\    }
        \\    if ((blk: {
        \\        _ = 2;
        \\        break :blk 5;
        \\    }) != 0) {
        \\        var a: c_int = 2;
        \\    }
        \\}
    });

    cases.add_2("while loops",
        \\int foo() {
        \\    int a = 5;
        \\    while (2)
        \\        a = 2;
        \\    while (4) {
        \\        int a = 4;
        \\        a = 9;
        \\        return 6, a;
        \\    }
        \\    do {
        \\        int a = 2;
        \\        a = 12;
        \\    } while (4);
        \\    do
        \\        a = 7;
        \\    while (4);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    var a: c_int = 5;
        \\    while (2 != 0) a = 2;
        \\    while (4 != 0) {
        \\        var a: c_int = 4;
        \\        a = 9;
        \\        _ = 6;
        \\        return a;
        \\    }
        \\    while (true) {
        \\        var a: c_int = 2;
        \\        a = 12;
        \\        if (!(4 != 0)) break;
        \\    }
        \\    while (true) {
        \\        a = 7;
        \\        if (!(4 != 0)) break;
        \\    }
        \\}
    });

    cases.add_2("for loops",
        \\int foo() {
        \\    for (int i = 2, b = 4; i + 2; i = 2) {
        \\        int a = 2;
        \\        a = 6, 5, 7;
        \\    }
        \\    char i = 2;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    {
        \\        var i: c_int = 2;
        \\        var b: c_int = 4;
        \\        while ((i + 2) != 0) : (i = 2) {
        \\            var a: c_int = 2;
        \\            a = 6;
        \\            _ = 5;
        \\            _ = 7;
        \\        }
        \\    }
        \\    var i: u8 = @as(u8, 2);
        \\}
    });

    cases.add_2("shadowing primitive types",
        \\unsigned anyerror = 2;
    , &[_][]const u8{
        \\pub export var _anyerror: c_uint = @as(c_uint, 2);
    });

    cases.add_2("floats",
        \\float a = 3.1415;
        \\double b = 3.1415;
        \\int c = 3.1415;
        \\double d = 3;
    , &[_][]const u8{
        \\pub export var a: f32 = @floatCast(f32, 3.1415);
        \\pub export var b: f64 = 3.1415;
        \\pub export var c: c_int = @floatToInt(c_int, 3.1415);
        \\pub export var d: f64 = @intToFloat(f64, 3);
    });

    cases.add_2("conditional operator",
        \\int bar(void) {
        \\    if (2 ? 5 : 5 ? 4 : 6) 2;
        \\    return  2 ? 5 : 5 ? 4 : 6;
        \\}
    , &[_][]const u8{
        \\pub export fn bar() c_int {
        \\    if ((if (2 != 0) 5 else (if (5 != 0) 4 else 6)) != 0) _ = 2;
        \\    return if (2 != 0) 5 else if (5 != 0) 4 else 6;
        \\}
    });

    cases.add_2("switch on int",
        \\int switch_fn(int i) {
        \\    int res = 0;
        \\    switch (i) {
        \\        case 0:
        \\            res = 1;
        \\        case 1 ... 3:
        \\            res = 2;
        \\        default:
        \\            res = 3 * i;
        \\            break;
        \\        case 4:
        \\            res = 5;
        \\    }
        \\}
    , &[_][]const u8{
        \\pub export fn switch_fn(_arg_i: c_int) c_int {
        \\    var i = _arg_i;
        \\    var res: c_int = 0;
        \\    __switch: {
        \\        __case_2: {
        \\            __default: {
        \\                __case_1: {
        \\                    __case_0: {
        \\                        switch (i) {
        \\                            0 => break :__case_0,
        \\                            1...3 => break :__case_1,
        \\                            else => break :__default,
        \\                            4 => break :__case_2,
        \\                        }
        \\                    }
        \\                    res = 1;
        \\                }
        \\                res = 2;
        \\            }
        \\            res = (3 * i);
        \\            break :__switch;
        \\        }
        \\        res = 5;
        \\    }
        \\}
    });

    cases.add_2("type referenced struct",
        \\struct Foo {
        \\    struct Bar{
        \\        int b;
        \\    };
        \\    struct Bar c;
        \\};
    , &[_][]const u8{
        \\pub const struct_Bar = extern struct {
        \\    b: c_int,
        \\};
        \\pub const struct_Foo = extern struct {
        \\    c: struct_Bar,
        \\};
    });

    cases.add_2("undefined array global",
        \\int array[100] = {};
    , &[_][]const u8{
        \\pub export var array: [100]c_int = .{0} ** 100;
    });

    cases.add_2("restrict -> noalias",
        \\void foo(void *restrict bar, void *restrict);
    , &[_][]const u8{
        \\pub extern fn foo(noalias bar: ?*c_void, noalias ?*c_void) void;
    });

    cases.add_2("assign",
        \\int max(int a) {
        \\    int tmp;
        \\    tmp = a;
        \\    a = tmp;
        \\}
    , &[_][]const u8{
        \\pub export fn max(_arg_a: c_int) c_int {
        \\    var a = _arg_a;
        \\    var tmp: c_int = undefined;
        \\    tmp = a;
        \\    a = tmp;
        \\}
    });

    cases.add_2("chaining assign",
        \\void max(int a) {
        \\    int b, c;
        \\    c = b = a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(_arg_a: c_int) void {
        \\    var a = _arg_a;
        \\    var b: c_int = undefined;
        \\    var c: c_int = undefined;
        \\    c = blk: {
        \\        const _tmp_1 = a;
        \\        b = _tmp_1;
        \\        break :blk _tmp_1;
        \\    };
        \\}
    });

    cases.add_2("anonymous enum",
        \\enum {
        \\    One,
        \\    Two,
        \\};
    , &[_][]const u8{
        \\pub const One = 0;
        \\pub const Two = 1;
        \\const enum_unnamed_1 = extern enum {
        \\    One,
        \\    Two,
        \\};
    });

    cases.add_2("c style cast",
        \\int float_to_int(float a) {
        \\    return (int)a;
        \\}
    , &[_][]const u8{
        \\pub export fn float_to_int(_arg_a: f32) c_int {
        \\    var a = _arg_a;
        \\    return @floatToInt(c_int, a);
        \\}
    });

    cases.add_2("escape sequences",
        \\const char *escapes() {
        \\char a = '\'',
        \\    b = '\\',
        \\    c = '\a',
        \\    d = '\b',
        \\    e = '\f',
        \\    f = '\n',
        \\    g = '\r',
        \\    h = '\t',
        \\    i = '\v',
        \\    j = '\0',
        \\    k = '\"';
        \\    return "\'\\\a\b\f\n\r\t\v\0\"";
        \\}
        \\
    , &[_][]const u8{
        \\pub export fn escapes() [*c]const u8 {
        \\    var a: u8 = @as(u8, '\'');
        \\    var b: u8 = @as(u8, '\\');
        \\    var c: u8 = @as(u8, '\x07');
        \\    var d: u8 = @as(u8, '\x08');
        \\    var e: u8 = @as(u8, '\x0c');
        \\    var f: u8 = @as(u8, '\n');
        \\    var g: u8 = @as(u8, '\r');
        \\    var h: u8 = @as(u8, '\t');
        \\    var i: u8 = @as(u8, '\x0b');
        \\    var j: u8 = @as(u8, '\x00');
        \\    var k: u8 = @as(u8, '\"');
        \\    return "\'\\\x07\x08\x0c\n\r\t\x0b\x00\"";
        \\}
    });

    cases.add_2("do loop",
        \\void foo(void) {
        \\    int a = 2;
        \\    do {
        \\        a = a - 1;
        \\    } while (a);
        \\
        \\    int b = 2;
        \\    do
        \\        b = b -1;
        \\    while (b);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = 2;
        \\    while (true) {
        \\        a = (a - 1);
        \\        if (!(a != 0)) break;
        \\    }
        \\    var b: c_int = 2;
        \\    while (true) {
        \\        b = (b - 1);
        \\        if (!(b != 0)) break;
        \\    }
        \\}
    });

    cases.add_2("logical and, logical or, on non-bool values, extra parens",
        \\enum Foo {
        \\    FooA,
        \\    FooB,
        \\    FooC,
        \\};
        \\typedef int SomeTypedef;
        \\int and_or_non_bool(int a, float b, void *c) {
        \\    enum Foo d = FooA;
        \\    int e = (a && b);
        \\    int f = (b && c);
        \\    int g = (a && c);
        \\    int h = (a || b);
        \\    int i = (b || c);
        \\    int j = (a || c);
        \\    int k = (a || d);
        \\    int l = (d && b);
        \\    int m = (c || d);
        \\    SomeTypedef td = 44;
        \\    int o = (td || b);
        \\    int p = (c && td);
        \\    return ((((((((((e + f) + g) + h) + i) + j) + k) + l) + m) + o) + p);
        \\}
    , &[_][]const u8{
        \\pub const enum_Foo = extern enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\pub const SomeTypedef = c_int;
        \\pub export fn and_or_non_bool(_arg_a: c_int, _arg_b: f32, _arg_c: ?*c_void) c_int {
        \\    var a = _arg_a;
        \\    var b = _arg_b;
        \\    var c = _arg_c;
        \\    var d: enum_Foo = @intToEnum(enum_Foo, FooA);
        \\    var e: c_int = @boolToInt(((a != 0) and (b != 0)));
        \\    var f: c_int = @boolToInt(((b != 0) and (c != null)));
        \\    var g: c_int = @boolToInt(((a != 0) and (c != null)));
        \\    var h: c_int = @boolToInt(((a != 0) or (b != 0)));
        \\    var i: c_int = @boolToInt(((b != 0) or (c != null)));
        \\    var j: c_int = @boolToInt(((a != 0) or (c != null)));
        \\    var k: c_int = @boolToInt(((a != 0) or (@enumToInt(d) != 0)));
        \\    var l: c_int = @boolToInt(((@enumToInt(d) != 0) and (b != 0)));
        \\    var m: c_int = @boolToInt(((c != null) or (@enumToInt(d) != 0)));
        \\    var td: SomeTypedef = 44;
        \\    var o: c_int = @boolToInt(((td != 0) or (b != 0)));
        \\    var p: c_int = @boolToInt(((c != null) and (td != 0)));
        \\    return ((((((((((e + f) + g) + h) + i) + j) + k) + l) + m) + o) + p);
        \\}
    ,
        \\pub const Foo = enum_Foo;
    });

    cases.add_2("qualified struct and enum",
        \\struct Foo {
        \\    int x;
        \\    int y;
        \\};
        \\enum Bar {
        \\    BarA,
        \\    BarB,
        \\};
        \\void func(struct Foo *a, enum Bar **b);
    , &[_][]const u8{
        \\pub const struct_Foo = extern struct {
        \\    x: c_int,
        \\    y: c_int,
        \\};
    ,
        \\pub const enum_Bar = extern enum {
        \\    A,
        \\    B,
        \\};
        \\pub extern fn func(a: [*c]struct_Foo, b: [*c][*c]enum_Bar) void;
    ,
        \\pub const Foo = struct_Foo;
        \\pub const Bar = enum_Bar;
    });

    cases.add_2("bitwise binary operators, simpler parens",
        \\int max(int a, int b) {
        \\    return (a & b) ^ (a | b);
        \\}
    , &[_][]const u8{
        \\pub export fn max(_arg_a: c_int, _arg_b: c_int) c_int {
        \\    var a = _arg_a;
        \\    var b = _arg_b;
        \\    return ((a & b) ^ (a | b));
        \\}
    });

    cases.add_2("comparison operators (no if)", // TODO Come up with less contrived tests? Make sure to cover all these comparisons.
        \\int test_comparisons(int a, int b) {
        \\    int c = (a < b);
        \\    int d = (a > b);
        \\    int e = (a <= b);
        \\    int f = (a >= b);
        \\    int g = (c < d);
        \\    int h = (e < f);
        \\    int i = (g < h);
        \\    return i;
        \\}
    , &[_][]const u8{
        \\pub export fn test_comparisons(_arg_a: c_int, _arg_b: c_int) c_int {
        \\    var a = _arg_a;
        \\    var b = _arg_b;
        \\    var c: c_int = @boolToInt((a < b));
        \\    var d: c_int = @boolToInt((a > b));
        \\    var e: c_int = @boolToInt((a <= b));
        \\    var f: c_int = @boolToInt((a >= b));
        \\    var g: c_int = @boolToInt((c < d));
        \\    var h: c_int = @boolToInt((e < f));
        \\    var i: c_int = @boolToInt((g < h));
        \\    return i;
        \\}
    });

    cases.add_2("==, !=",
        \\int max(int a, int b) {
        \\    if (a == b)
        \\        return a;
        \\    if (a != b)
        \\        return b;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(_arg_a: c_int, _arg_b: c_int) c_int {
        \\    var a = _arg_a;
        \\    var b = _arg_b;
        \\    if (a == b) return a;
        \\    if (a != b) return b;
        \\    return a;
        \\}
    });

    cases.add_2("typedeffed bool expression",
        \\typedef char* yes;
        \\void foo(void) {
        \\    yes a;
        \\    if (a) 2;
        \\}
    , &[_][]const u8{
        \\pub const yes = [*c]u8;
        \\pub export fn foo() void {
        \\    var a: yes = undefined;
        \\    if (a != null) _ = 2;
        \\}
    });

    cases.add_2("statement expression",
        \\int foo(void) {
        \\    return ({
        \\        int a = 1;
        \\        a;
        \\        a;
        \\    });
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return (blk: {
        \\        var a: c_int = 1;
        \\        _ = a;
        \\        break :blk a;
        \\    });
        \\}
    });

    cases.add_2("field access expression",
        \\#define ARROW a->b
        \\#define DOT a.b
        \\extern struct Foo {
        \\    int b;
        \\}a;
        \\float b = 2.0f;
        \\int foo(void) {
        \\    struct Foo *c;
        \\    a.b;
        \\    c->b;
        \\}
    , &[_][]const u8{
        \\pub const struct_Foo = extern struct {
        \\    b: c_int,
        \\};
        \\pub extern var a: struct_Foo;
        \\pub export var b: f32 = 2;
        \\pub export fn foo() c_int {
        \\    var c: [*c]struct_Foo = undefined;
        \\    _ = a.b;
        \\    _ = c.*.b;
        \\}
    ,
        \\pub const DOT = a.b;
    ,
        \\pub const ARROW = a.*.b;
    });

    cases.add_2("array access",
        \\#define ACCESS array[2]
        \\int array[100] = {};
        \\int foo(int index) {
        \\    return array[index];
        \\}
    , &[_][]const u8{
        \\pub export var array: [100]c_int = .{0} ** 100;
        \\pub export fn foo(_arg_index: c_int) c_int {
        \\    var index = _arg_index;
        \\    return array[index];
        \\}
    ,
        \\pub const ACCESS = array[2];
    });

    cases.add_2("macro call",
        \\#define CALL(arg) bar(arg)
    , &[_][]const u8{
        \\pub inline fn CALL(arg: var) @TypeOf(bar(arg)) {
        \\    return bar(arg);
        \\}
    });

    cases.add_2("logical and, logical or",
        \\int max(int a, int b) {
        \\    if (a < b || a == b)
        \\        return b;
        \\    if (a >= b && a == b)
        \\        return a;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(_arg_a: c_int, _arg_b: c_int) c_int {
        \\    var a = _arg_a;
        \\    var b = _arg_b;
        \\    if ((a < b) or (a == b)) return b;
        \\    if ((a >= b) and (a == b)) return a;
        \\    return a;
        \\}
    });

    cases.add_2("if statement",
        \\int max(int a, int b) {
        \\    if (a < b)
        \\        return b;
        \\
        \\    if (a < b)
        \\        return b;
        \\    else
        \\        return a;
        \\
        \\    if (a < b) ; else ;
        \\}
    , &[_][]const u8{
        \\pub export fn max(_arg_a: c_int, _arg_b: c_int) c_int {
        \\    var a = _arg_a;
        \\    var b = _arg_b;
        \\    if (a < b) return b;
        \\    if (a < b) return b else return a;
        \\    if (a < b) {} else {}
        \\}
    });

    cases.add_2("if on non-bool",
        \\enum SomeEnum { A, B, C };
        \\int if_none_bool(int a, float b, void *c, enum SomeEnum d) {
        \\    if (a) return 0;
        \\    if (b) return 1;
        \\    if (c) return 2;
        \\    if (d) return 3;
        \\    return 4;
        \\}
    , &[_][]const u8{
        \\pub const enum_SomeEnum = extern enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\pub export fn if_none_bool(_arg_a: c_int, _arg_b: f32, _arg_c: ?*c_void, _arg_d: enum_SomeEnum) c_int {
        \\    var a = _arg_a;
        \\    var b = _arg_b;
        \\    var c = _arg_c;
        \\    var d = _arg_d;
        \\    if (a != 0) return 0;
        \\    if (b != 0) return 1;
        \\    if (c != null) return 2;
        \\    if (d != 0) return 3;
        \\    return 4;
        \\}
    });

    cases.add_2("simple data types",
        \\#include <stdint.h>
        \\int foo(char a, unsigned char b, signed char c);
        \\int foo(char a, unsigned char b, signed char c); // test a duplicate prototype
        \\void bar(uint8_t a, uint16_t b, uint32_t c, uint64_t d);
        \\void baz(int8_t a, int16_t b, int32_t c, int64_t d);
    , &[_][]const u8{
        \\pub extern fn foo(a: u8, b: u8, c: i8) c_int;
        \\pub extern fn bar(a: u8, b: u16, c: u32, d: u64) void;
        \\pub extern fn baz(a: i8, b: i16, c: i32, d: i64) void;
    });

    cases.add_2("simple function",
        \\int abs(int a) {
        \\    return a < 0 ? -a : a;
        \\}
    , &[_][]const u8{
        \\pub export fn abs(_arg_a: c_int) c_int {
        \\    var a = _arg_a;
        \\    return if (a < 0) -a else a;
        \\}
    });

    cases.add_2("post increment",
        \\unsigned foo1(unsigned a) {
        \\    a++;
        \\    return a;
        \\}
        \\int foo2(int a) {
        \\    a++;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn foo1(_arg_a: c_uint) c_uint {
        \\    var a = _arg_a;
        \\    a +%= 1;
        \\    return a;
        \\}
        \\pub export fn foo2(_arg_a: c_int) c_int {
        \\    var a = _arg_a;
        \\    a += 1;
        \\    return a;
        \\}
    });

    cases.add_2("deref function pointer",
        \\void foo(void) {}
        \\int baz(void) { return 0; }
        \\void bar(void) {
        \\    void(*f)(void) = foo;
        \\    int(*b)(void) = baz;
        \\    f();
        \\    (*(f))();
        \\    foo();
        \\    b();
        \\    (*(b))();
        \\    baz();
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {}
        \\pub export fn baz() c_int {
        \\    return 0;
        \\}
        \\pub export fn bar() void {
        \\    var f: ?extern fn () void = foo;
        \\    var b: ?extern fn () c_int = baz;
        \\    f.?();
        \\    (f).?();
        \\    foo();
        \\    _ = b.?();
        \\    _ = (b).?();
        \\    _ = baz();
        \\}
    });

    cases.add_2("pre increment/decrement",
        \\void foo(void) {
        \\    int i = 0;
        \\    unsigned u = 0;
        \\    ++i;
        \\    --i;
        \\    ++u;
        \\    --u;
        \\    i = ++i;
        \\    i = --i;
        \\    u = ++u;
        \\    u = --u;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var i: c_int = 0;
        \\    var u: c_uint = @as(c_uint, 0);
        \\    i += 1;
        \\    i -= 1;
        \\    u +%= 1;
        \\    u -%= 1;
        \\    i = (blk: {
        \\        const _ref_1 = &i;
        \\        _ref_1.* += 1;
        \\        break :blk _ref_1.*;
        \\    });
        \\    i = (blk: {
        \\        const _ref_2 = &i;
        \\        _ref_2.* -= 1;
        \\        break :blk _ref_2.*;
        \\    });
        \\    u = (blk: {
        \\        const _ref_3 = &u;
        \\        _ref_3.* +%= 1;
        \\        break :blk _ref_3.*;
        \\    });
        \\    u = (blk: {
        \\        const _ref_4 = &u;
        \\        _ref_4.* -%= 1;
        \\        break :blk _ref_4.*;
        \\    });
        \\}
    });

    cases.add_2("shift right assign",
        \\int log2(unsigned a) {
        \\    int i = 0;
        \\    while (a > 0) {
        \\        a >>= 1;
        \\    }
        \\    return i;
        \\}
    , &[_][]const u8{
        \\pub export fn log2(_arg_a: c_uint) c_int {
        \\    var a = _arg_a;
        \\    var i: c_int = 0;
        \\    while (a > @as(c_uint, 0)) {
        \\        a >>= @as(@import("std").math.Log2Int(c_int), 1);
        \\    }
        \\    return i;
        \\}
    });

    cases.add_2("shift right assign with a fixed size type",
        \\#include <stdint.h>
        \\int log2(uint32_t a) {
        \\    int i = 0;
        \\    while (a > 0) {
        \\        a >>= 1;
        \\    }
        \\    return i;
        \\}
    , &[_][]const u8{
        \\pub export fn log2(_arg_a: u32) c_int {
        \\    var a = _arg_a;
        \\    var i: c_int = 0;
        \\    while (a > @as(c_uint, 0)) {
        \\        a >>= @as(@import("std").math.Log2Int(c_int), 1);
        \\    }
        \\    return i;
        \\}
    });

    cases.add_2("compound assignment operators",
        \\void foo(void) {
        \\    int a = 0;
        \\    a += (a += 1);
        \\    a -= (a -= 1);
        \\    a *= (a *= 1);
        \\    a &= (a &= 1);
        \\    a |= (a |= 1);
        \\    a ^= (a ^= 1);
        \\    a >>= (a >>= 1);
        \\    a <<= (a <<= 1);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = 0;
        \\    a += (blk: {
        \\        const _ref_1 = &a;
        \\        _ref_1.* = _ref_1.* + 1;
        \\        break :blk _ref_1.*;
        \\    });
        \\    a -= (blk: {
        \\        const _ref_2 = &a;
        \\        _ref_2.* = _ref_2.* - 1;
        \\        break :blk _ref_2.*;
        \\    });
        \\    a *= (blk: {
        \\        const _ref_3 = &a;
        \\        _ref_3.* = _ref_3.* * 1;
        \\        break :blk _ref_3.*;
        \\    });
        \\    a &= (blk: {
        \\        const _ref_4 = &a;
        \\        _ref_4.* = _ref_4.* & 1;
        \\        break :blk _ref_4.*;
        \\    });
        \\    a |= (blk: {
        \\        const _ref_5 = &a;
        \\        _ref_5.* = _ref_5.* | 1;
        \\        break :blk _ref_5.*;
        \\    });
        \\    a ^= (blk: {
        \\        const _ref_6 = &a;
        \\        _ref_6.* = _ref_6.* ^ 1;
        \\        break :blk _ref_6.*;
        \\    });
        \\    a >>= @as(@import("std").math.Log2Int(c_int), (blk: {
        \\        const _ref_7 = &a;
        \\        _ref_7.* = _ref_7.* >> @as(@import("std").math.Log2Int(c_int), 1);
        \\        break :blk _ref_7.*;
        \\    }));
        \\    a <<= @as(@import("std").math.Log2Int(c_int), (blk: {
        \\        const _ref_8 = &a;
        \\        _ref_8.* = _ref_8.* << @as(@import("std").math.Log2Int(c_int), 1);
        \\        break :blk _ref_8.*;
        \\    }));
        \\}
    });

    cases.add_2("compound assignment operators unsigned",
        \\void foo(void) {
        \\    unsigned a = 0;
        \\    a += (a += 1);
        \\    a -= (a -= 1);
        \\    a *= (a *= 1);
        \\    a &= (a &= 1);
        \\    a |= (a |= 1);
        \\    a ^= (a ^= 1);
        \\    a >>= (a >>= 1);
        \\    a <<= (a <<= 1);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_uint = @as(c_uint, 0);
        \\    a +%= (blk: {
        \\        const _ref_1 = &a;
        \\        _ref_1.* = _ref_1.* +% @as(c_uint, 1);
        \\        break :blk _ref_1.*;
        \\    });
        \\    a -%= (blk: {
        \\        const _ref_2 = &a;
        \\        _ref_2.* = _ref_2.* -% @as(c_uint, 1);
        \\        break :blk _ref_2.*;
        \\    });
        \\    a *%= (blk: {
        \\        const _ref_3 = &a;
        \\        _ref_3.* = _ref_3.* *% @as(c_uint, 1);
        \\        break :blk _ref_3.*;
        \\    });
        \\    a &= (blk: {
        \\        const _ref_4 = &a;
        \\        _ref_4.* = _ref_4.* & @as(c_uint, 1);
        \\        break :blk _ref_4.*;
        \\    });
        \\    a |= (blk: {
        \\        const _ref_5 = &a;
        \\        _ref_5.* = _ref_5.* | @as(c_uint, 1);
        \\        break :blk _ref_5.*;
        \\    });
        \\    a ^= (blk: {
        \\        const _ref_6 = &a;
        \\        _ref_6.* = _ref_6.* ^ @as(c_uint, 1);
        \\        break :blk _ref_6.*;
        \\    });
        \\    a >>= @as(@import("std").math.Log2Int(c_uint), (blk: {
        \\        const _ref_7 = &a;
        \\        _ref_7.* = _ref_7.* >> @as(@import("std").math.Log2Int(c_int), 1);
        \\        break :blk _ref_7.*;
        \\    }));
        \\    a <<= @as(@import("std").math.Log2Int(c_uint), (blk: {
        \\        const _ref_8 = &a;
        \\        _ref_8.* = _ref_8.* << @as(@import("std").math.Log2Int(c_int), 1);
        \\        break :blk _ref_8.*;
        \\    }));
        \\}
    });

    cases.add_2("post increment/decrement",
        \\void foo(void) {
        \\    int i = 0;
        \\    unsigned u = 0;
        \\    i++;
        \\    i--;
        \\    u++;
        \\    u--;
        \\    i = i++;
        \\    i = i--;
        \\    u = u++;
        \\    u = u--;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var i: c_int = 0;
        \\    var u: c_uint = @as(c_uint, 0);
        \\    i += 1;
        \\    i -= 1;
        \\    u +%= 1;
        \\    u -%= 1;
        \\    i = (blk: {
        \\        const _ref_1 = &i;
        \\        const _tmp_2 = _ref_1.*;
        \\        _ref_1.* += 1;
        \\        break :blk _tmp_2;
        \\    });
        \\    i = (blk: {
        \\        const _ref_3 = &i;
        \\        const _tmp_4 = _ref_3.*;
        \\        _ref_3.* -= 1;
        \\        break :blk _tmp_4;
        \\    });
        \\    u = (blk: {
        \\        const _ref_5 = &u;
        \\        const _tmp_6 = _ref_5.*;
        \\        _ref_5.* +%= 1;
        \\        break :blk _tmp_6;
        \\    });
        \\    u = (blk: {
        \\        const _ref_7 = &u;
        \\        const _tmp_8 = _ref_7.*;
        \\        _ref_7.* -%= 1;
        \\        break :blk _tmp_8;
        \\    });
        \\}
    });

    cases.add_2("implicit casts",
        \\#include <stdbool.h>
        \\
        \\void fn_int(int x);
        \\void fn_f32(float x);
        \\void fn_f64(double x);
        \\void fn_char(char x);
        \\void fn_bool(bool x);
        \\void fn_ptr(void *x);
        \\
        \\void call(int q) {
        \\    fn_int(3.0f);
        \\    fn_int(3.0);
        \\    fn_int(3.0L);
        \\    fn_int('ABCD');
        \\    fn_f32(3);
        \\    fn_f64(3);
        \\    fn_char('3');
        \\    fn_char('\x1');
        \\    fn_char(0);
        \\    fn_f32(3.0f);
        \\    fn_f64(3.0);
        \\    fn_bool(123);
        \\    fn_bool(0);
        \\    fn_bool(&fn_int);
        \\    fn_int(&fn_int);
        \\    fn_ptr(42);
        \\}
    , &[_][]const u8{
        \\pub extern fn fn_int(x: c_int) void;
        \\pub extern fn fn_f32(x: f32) void;
        \\pub extern fn fn_f64(x: f64) void;
        \\pub extern fn fn_char(x: u8) void;
        \\pub extern fn fn_bool(x: bool) void;
        \\pub extern fn fn_ptr(x: ?*c_void) void;
        \\pub export fn call(_arg_q: c_int) void {
        \\    var q = _arg_q;
        \\    fn_int(@floatToInt(c_int, 3));
        \\    fn_int(@floatToInt(c_int, 3));
        \\    fn_int(@floatToInt(c_int, 3));
        \\    fn_int(1094861636);
        \\    fn_f32(@intToFloat(f32, 3));
        \\    fn_f64(@intToFloat(f64, 3));
        \\    fn_char(@as(u8, '3'));
        \\    fn_char(@as(u8, '\x01'));
        \\    fn_char(@as(u8, 0));
        \\    fn_f32(3);
        \\    fn_f64(3);
        \\    fn_bool(123 != 0);
        \\    fn_bool(0 != 0);
        \\    fn_bool(@ptrToInt(&fn_int) != 0);
        \\    fn_int(@intCast(c_int, @ptrToInt(&fn_int)));
        \\    fn_ptr(@intToPtr(?*c_void, 42));
        \\}
    });

    cases.add_2("function call",
        \\static void bar(void) { }
        \\void foo(int *(baz)(void)) {
        \\    bar();
        \\    baz();
        \\}
    , &[_][]const u8{
        \\pub fn bar() void {}
        \\pub export fn foo(_arg_baz: ?extern fn () [*c]c_int) void {
        \\    var baz = _arg_baz;
        \\    bar();
        \\    _ = baz.?();
        \\}
    });

    cases.add_2("macro defines string literal with octal",
        \\#define FOO "aoeu\023 derp"
        \\#define FOO2 "aoeu\0234 derp"
        \\#define FOO_CHAR '\077'
    , &[_][]const u8{
        \\pub const FOO = "aoeu\x13 derp";
    ,
        \\pub const FOO2 = "aoeu\x134 derp";
    ,
        \\pub const FOO_CHAR = '\x3f';
    });

    cases.add_2("enums",
        \\enum Foo {
        \\    FooA,
        \\    FooB,
        \\    Foo1,
        \\};
    , &[_][]const u8{
        \\pub const enum_Foo = extern enum {
        \\    A,
        \\    B,
        \\    @"1",
        \\};
    ,
        \\pub const FooA = 0;
    ,
        \\pub const FooB = 1;
    ,
        \\pub const Foo1 = 2;
    ,
        \\pub const Foo = enum_Foo;
    });

    cases.add_2("enums",
        \\enum Foo {
        \\    FooA = 2,
        \\    FooB = 5,
        \\    Foo1,
        \\};
    , &[_][]const u8{
        \\pub const enum_Foo = extern enum {
        \\    A = 2,
        \\    B = 5,
        \\    @"1" = 6,
        \\};
    ,
        \\pub const FooA = 2;
    ,
        \\pub const FooB = 5;
    ,
        \\pub const Foo1 = 6;
    ,
        \\pub const Foo = enum_Foo;
    });

    cases.add_2("macro cast",
    \\#define FOO(bar) baz((void *)(baz))
    , &[_][]const u8{
        \\pub inline fn FOO(bar: var) @TypeOf(baz(if (@typeId(@TypeOf(baz)) == .Pointer) @ptrCast([*c]void, baz) else if (@typeId(@TypeOf(baz)) == .Int) @intToPtr([*c]void, baz) else @as([*c]void, baz))) {
        \\    return baz(if (@typeId(@TypeOf(baz)) == .Pointer) @ptrCast([*c]void, baz) else if (@typeId(@TypeOf(baz)) == .Int) @intToPtr([*c]void, baz) else @as([*c]void, baz));
        \\}
    });

    /////////////// Cases for only stage1 because stage2 behavior is better ////////////////
    cases.addC("Parameterless function prototypes",
        \\void foo() {}
        \\void bar(void) {}
    , &[_][]const u8{
        \\pub export fn foo() void {}
        \\pub export fn bar() void {}
    });

    cases.add("#define a char literal",
        \\#define A_CHAR  'a'
    , &[_][]const u8{
        \\pub const A_CHAR = 97;
    });

    cases.add("generate inline func for #define global extern fn",
        \\extern void (*fn_ptr)(void);
        \\#define foo fn_ptr
        \\
        \\extern char (*fn_ptr2)(int, float);
        \\#define bar fn_ptr2
    , &[_][]const u8{
        \\pub extern var fn_ptr: ?extern fn () void;
    ,
        \\pub inline fn foo() void {
        \\    return fn_ptr.?();
        \\}
    ,
        \\pub extern var fn_ptr2: ?extern fn (c_int, f32) u8;
    ,
        \\pub inline fn bar(arg0: c_int, arg1: f32) u8 {
        \\    return fn_ptr2.?(arg0, arg1);
        \\}
    });
    cases.add("comment after integer literal",
        \\#define SDL_INIT_VIDEO 0x00000020  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = 32;
    });

    cases.add("u integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020u  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_uint, 32);
    });

    cases.add("l integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020l  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_long, 32);
    });

    cases.add("ul integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ul  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulong, 32);
    });

    cases.add("lu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020lu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulong, 32);
    });

    cases.add("ll integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ll  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_longlong, 32);
    });

    cases.add("ull integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ull  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulonglong, 32);
    });

    cases.add("llu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020llu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulonglong, 32);
    });

    cases.add("macros with field targets",
        \\typedef unsigned int GLbitfield;
        \\typedef void (*PFNGLCLEARPROC) (GLbitfield mask);
        \\typedef void(*OpenGLProc)(void);
        \\union OpenGLProcs {
        \\    OpenGLProc ptr[1];
        \\    struct {
        \\        PFNGLCLEARPROC Clear;
        \\    } gl;
        \\};
        \\extern union OpenGLProcs glProcs;
        \\#define glClearUnion glProcs.gl.Clear
        \\#define glClearPFN PFNGLCLEARPROC
    , &[_][]const u8{
        \\pub const GLbitfield = c_uint;
    ,
        \\pub const PFNGLCLEARPROC = ?extern fn (GLbitfield) void;
    ,
        \\pub const OpenGLProc = ?extern fn () void;
    ,
        \\pub const union_OpenGLProcs = extern union {
        \\    ptr: [1]OpenGLProc,
        \\    gl: extern struct {
        \\        Clear: PFNGLCLEARPROC,
        \\    },
        \\};
    ,
        \\pub extern var glProcs: union_OpenGLProcs;
    ,
        \\pub const glClearPFN = PFNGLCLEARPROC;
    ,
        \\pub inline fn glClearUnion(arg0: GLbitfield) void {
        \\    return glProcs.gl.Clear.?(arg0);
        \\}
    ,
        \\pub const OpenGLProcs = union_OpenGLProcs;
    });

    cases.add("macro pointer cast",
        \\#define NRF_GPIO ((NRF_GPIO_Type *) NRF_GPIO_BASE)
    , &[_][]const u8{
        \\pub const NRF_GPIO = if (@typeId(@TypeOf(NRF_GPIO_BASE)) == @import("builtin").TypeId.Pointer) @ptrCast([*c]NRF_GPIO_Type, NRF_GPIO_BASE) else if (@typeId(@TypeOf(NRF_GPIO_BASE)) == @import("builtin").TypeId.Int) @intToPtr([*c]NRF_GPIO_Type, NRF_GPIO_BASE) else @as([*c]NRF_GPIO_Type, NRF_GPIO_BASE);
    });

    cases.add("switch on int",
        \\int switch_fn(int i) {
        \\    int res = 0;
        \\    switch (i) {
        \\        case 0:
        \\            res = 1;
        \\        case 1:
        \\            res = 2;
        \\        default:
        \\            res = 3 * i;
        \\            break;
        \\        case 2:
        \\            res = 5;
        \\    }
        \\}
    , &[_][]const u8{
        \\pub fn switch_fn(i: c_int) c_int {
        \\    var res: c_int = 0;
        \\    __switch: {
        \\        __case_2: {
        \\            __default: {
        \\                __case_1: {
        \\                    __case_0: {
        \\                        switch (i) {
        \\                            0 => break :__case_0,
        \\                            1 => break :__case_1,
        \\                            else => break :__default,
        \\                            2 => break :__case_2,
        \\                        }
        \\                    }
        \\                    res = 1;
        \\                }
        \\                res = 2;
        \\            }
        \\            res = (3 * i);
        \\            break :__switch;
        \\        }
        \\        res = 5;
        \\    }
        \\}
    });

    cases.add("for loop with var init but empty body",
        \\void foo(void) {
        \\    for (int x = 0; x < 10; x++);
        \\}
    , &[_][]const u8{
        \\pub fn foo() void {
        \\    {
        \\        var x: c_int = 0;
        \\        while (x < 10) : (x += 1) {}
        \\    }
        \\}
    });

    cases.add("do while with empty body",
        \\void foo(void) {
        \\    do ; while (1);
        \\}
    , &[_][]const u8{ // TODO this should be if (1 != 0) break
        \\pub fn foo() void {
        \\    while (true) {
        \\        {}
        \\        if (!1) break;
        \\    }
        \\}
    });

    cases.add("for with empty body",
        \\void foo(void) {
        \\    for (;;);
        \\}
    , &[_][]const u8{
        \\pub fn foo() void {
        \\    while (true) {}
        \\}
    });

    cases.add("while with empty body",
        \\void foo(void) {
        \\    while (1);
        \\}
    , &[_][]const u8{
        \\pub fn foo() void {
        \\    while (1 != 0) {}
        \\}
    });

    cases.add("undefined array global",
        \\int array[100];
    , &[_][]const u8{
        \\pub var array: [100]c_int = undefined;
    });

    cases.add("qualified struct and enum",
        \\struct Foo {
        \\    int x;
        \\    int y;
        \\};
        \\enum Bar {
        \\    BarA,
        \\    BarB,
        \\};
        \\void func(struct Foo *a, enum Bar **b);
    , &[_][]const u8{
        \\pub const struct_Foo = extern struct {
        \\    x: c_int,
        \\    y: c_int,
        \\};
    ,
        \\pub const enum_Bar = extern enum {
        \\    A,
        \\    B,
        \\};
    ,
        \\pub const BarA = enum_Bar.A;
    ,
        \\pub const BarB = enum_Bar.B;
    ,
        \\pub extern fn func(a: [*c]struct_Foo, b: [*c]([*c]enum_Bar)) void;
    ,
        \\pub const Foo = struct_Foo;
    ,
        \\pub const Bar = enum_Bar;
    });

    cases.add("restrict -> noalias",
        \\void foo(void *restrict bar, void *restrict);
    , &[_][]const u8{
        \\pub extern fn foo(noalias bar: ?*c_void, noalias arg1: ?*c_void) void;
    });

    cases.addC("assign",
        \\int max(int a) {
        \\    int tmp;
        \\    tmp = a;
        \\    a = tmp;
        \\}
    , &[_][]const u8{
        \\pub export fn max(_arg_a: c_int) c_int {
        \\    var a = _arg_a;
        \\    var tmp: c_int = undefined;
        \\    tmp = a;
        \\    a = tmp;
        \\}
    });

    cases.addC("chaining assign",
        \\void max(int a) {
        \\    int b, c;
        \\    c = b = a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(a: c_int) void {
        \\    var b: c_int = undefined;
        \\    var c: c_int = undefined;
        \\    c = (x: {
        \\        const _tmp = a;
        \\        b = _tmp;
        \\        break :x _tmp;
        \\    });
        \\}
    });

    cases.add("anonymous enum",
        \\enum {
        \\    One,
        \\    Two,
        \\};
    , &[_][]const u8{
        \\pub const One = 0;
        \\pub const Two = 1;
    });

    cases.addC("c style cast",
        \\int float_to_int(float a) {
        \\    return (int)a;
        \\}
    , &[_][]const u8{
        \\pub export fn float_to_int(a: f32) c_int {
        \\    return @as(c_int, a);
        \\}
    });

    cases.addC("comma operator",
        \\int foo(void) {
        \\    return 1, 2;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return x: {
        \\        _ = 1;
        \\        break :x 2;
        \\    };
        \\}
    });

    cases.addC("escape sequences",
        \\const char *escapes() {
        \\char a = '\'',
        \\    b = '\\',
        \\    c = '\a',
        \\    d = '\b',
        \\    e = '\f',
        \\    f = '\n',
        \\    g = '\r',
        \\    h = '\t',
        \\    i = '\v',
        \\    j = '\0',
        \\    k = '\"';
        \\    return "\'\\\a\b\f\n\r\t\v\0\"";
        \\}
        \\
    , &[_][]const u8{
        \\pub export fn escapes() [*c]const u8 {
        \\    var a: u8 = @as(u8, '\'');
        \\    var b: u8 = @as(u8, '\\');
        \\    var c: u8 = @as(u8, '\x07');
        \\    var d: u8 = @as(u8, '\x08');
        \\    var e: u8 = @as(u8, '\x0c');
        \\    var f: u8 = @as(u8, '\n');
        \\    var g: u8 = @as(u8, '\r');
        \\    var h: u8 = @as(u8, '\t');
        \\    var i: u8 = @as(u8, '\x0b');
        \\    var j: u8 = @as(u8, '\x00');
        \\    var k: u8 = @as(u8, '\"');
        \\    return "\'\\\x07\x08\x0c\n\r\t\x0b\x00\"";
        \\}
        \\
    });

    cases.addC("do loop",
        \\void foo(void) {
        \\    int a = 2;
        \\    do {
        \\        a--;
        \\    } while (a != 0);
        \\
        \\    int b = 2;
        \\    do
        \\        b--;
        \\    while (b != 0);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = 2;
        \\    while (true) {
        \\        a -= 1;
        \\        if (!(a != 0)) break;
        \\    }
        \\    var b: c_int = 2;
        \\    while (true) {
        \\        b -= 1;
        \\        if (!(b != 0)) break;
        \\    }
        \\}
    });

    cases.addC("==, !=",
        \\int max(int a, int b) {
        \\    if (a == b)
        \\        return a;
        \\    if (a != b)
        \\        return b;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(a: c_int, b: c_int) c_int {
        \\    if (a == b) return a;
        \\    if (a != b) return b;
        \\    return a;
        \\}
    });

    cases.addC("bitwise binary operators",
        \\int max(int a, int b) {
        \\    return (a & b) ^ (a | b);
        \\}
    , &[_][]const u8{
        \\pub export fn max(a: c_int, b: c_int) c_int {
        \\    return (a & b) ^ (a | b);
        \\}
    });

    cases.addC("statement expression",
        \\int foo(void) {
        \\    return ({
        \\        int a = 1;
        \\        a;
        \\    });
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return x: {
        \\        var a: c_int = 1;
        \\        break :x a;
        \\    };
        \\}
    });

    cases.addC("field access expression",
        \\struct Foo {
        \\    int field;
        \\};
        \\int read_field(struct Foo *foo) {
        \\    return foo->field;
        \\}
    , &[_][]const u8{
        \\pub const struct_Foo = extern struct {
        \\    field: c_int,
        \\};
        \\pub export fn read_field(foo: [*c]struct_Foo) c_int {
        \\    return foo.*.field;
        \\}
    });

    cases.addC("array access",
        \\int array[100];
        \\int foo(int index) {
        \\    return array[index];
        \\}
    , &[_][]const u8{
        \\pub var array: [100]c_int = undefined;
        \\pub export fn foo(index: c_int) c_int {
        \\    return array[index];
        \\}
    });

    cases.addC("logical and, logical or",
        \\int max(int a, int b) {
        \\    if (a < b || a == b)
        \\        return b;
        \\    if (a >= b && a == b)
        \\        return a;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(a: c_int, b: c_int) c_int {
        \\    if ((a < b) or (a == b)) return b;
        \\    if ((a >= b) and (a == b)) return a;
        \\    return a;
        \\}
    });

    cases.addC("if statement",
        \\int max(int a, int b) {
        \\    if (a < b)
        \\        return b;
        \\
        \\    if (a < b)
        \\        return b;
        \\    else
        \\        return a;
        \\
        \\    if (a < b) ; else ;
        \\}
    , &[_][]const u8{
        \\pub export fn max(a: c_int, b: c_int) c_int {
        \\    if (a < b) return b;
        \\    if (a < b) return b else return a;
        \\    if (a < b) {} else {}
        \\}
    });

    cases.add("variable name shadowing",
        \\int foo(void) {
        \\    int x = 1;
        \\    {
        \\        int x = 2;
        \\        x += 1;
        \\    }
        \\    return x;
        \\}
    , &[_][]const u8{
        \\pub fn foo() c_int {
        \\    var x: c_int = 1;
        \\    {
        \\        var x_0: c_int = 2;
        \\        x_0 += 1;
        \\    }
        \\    return x;
        \\}
    });

    cases.add("if on non-bool",
        \\enum SomeEnum { A, B, C };
        \\int if_none_bool(int a, float b, void *c, enum SomeEnum d) {
        \\    if (a) return 0;
        \\    if (b) return 1;
        \\    if (c) return 2;
        \\    if (d) return 3;
        \\    return 4;
        \\}
    , &[_][]const u8{
        \\pub const A = enum_SomeEnum.A;
        \\pub const B = enum_SomeEnum.B;
        \\pub const C = enum_SomeEnum.C;
        \\pub const enum_SomeEnum = extern enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\pub fn if_none_bool(a: c_int, b: f32, c: ?*c_void, d: enum_SomeEnum) c_int {
        \\    if (a != 0) return 0;
        \\    if (b != 0) return 1;
        \\    if (c != null) return 2;
        \\    if (d != @bitCast(enum_SomeEnum, @as(@TagType(enum_SomeEnum), 0))) return 3;
        \\    return 4;
        \\}
    });

    cases.addAllowWarnings("simple data types",
        \\#include <stdint.h>
        \\int foo(char a, unsigned char b, signed char c);
        \\int foo(char a, unsigned char b, signed char c); // test a duplicate prototype
        \\void bar(uint8_t a, uint16_t b, uint32_t c, uint64_t d);
        \\void baz(int8_t a, int16_t b, int32_t c, int64_t d);
    , &[_][]const u8{
        \\pub extern fn foo(a: u8, b: u8, c: i8) c_int;
    ,
        \\pub extern fn bar(a: u8, b: u16, c: u32, d: u64) void;
    ,
        \\pub extern fn baz(a: i8, b: i16, c: i32, d: i64) void;
    });

    cases.addC("simple function",
        \\int abs(int a) {
        \\    return a < 0 ? -a : a;
        \\}
    , &[_][]const u8{
        \\pub export fn abs(a: c_int) c_int {
        \\    return if (a < 0) -a else a;
        \\}
    });

    cases.addC("post increment",
        \\unsigned foo1(unsigned a) {
        \\    a++;
        \\    return a;
        \\}
        \\int foo2(int a) {
        \\    a++;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn foo1(_arg_a: c_uint) c_uint {
        \\    var a = _arg_a;
        \\    a +%= 1;
        \\    return a;
        \\}
        \\pub export fn foo2(_arg_a: c_int) c_int {
        \\    var a = _arg_a;
        \\    a += 1;
        \\    return a;
        \\}
    });

    cases.addC("deref function pointer",
        \\void foo(void) {}
        \\int baz(void) { return 0; }
        \\void bar(void) {
        \\    void(*f)(void) = foo;
        \\    int(*b)(void) = baz;
        \\    f();
        \\    (*(f))();
        \\    foo();
        \\    b();
        \\    (*(b))();
        \\    baz();
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {}
        \\pub export fn baz() c_int {
        \\    return 0;
        \\}
        \\pub export fn bar() void {
        \\    var f: ?extern fn () void = foo;
        \\    var b: ?extern fn () c_int = baz;
        \\    f.?();
        \\    f.?();
        \\    foo();
        \\    _ = b.?();
        \\    _ = b.?();
        \\    _ = baz();
        \\}
    });

    cases.addC("pre increment/decrement",
        \\void foo(void) {
        \\    int i = 0;
        \\    unsigned u = 0;
        \\    ++i;
        \\    --i;
        \\    ++u;
        \\    --u;
        \\    i = ++i;
        \\    i = --i;
        \\    u = ++u;
        \\    u = --u;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var i: c_int = 0;
        \\    var u: c_uint = @as(c_uint, 0);
        \\    i += 1;
        \\    i -= 1;
        \\    u +%= 1;
        \\    u -%= 1;
        \\    i = (x: {
        \\        const _ref = &i;
        \\        _ref.* += 1;
        \\        break :x _ref.*;
        \\    });
        \\    i = (x: {
        \\        const _ref = &i;
        \\        _ref.* -= 1;
        \\        break :x _ref.*;
        \\    });
        \\    u = (x: {
        \\        const _ref = &u;
        \\        _ref.* +%= 1;
        \\        break :x _ref.*;
        \\    });
        \\    u = (x: {
        \\        const _ref = &u;
        \\        _ref.* -%= 1;
        \\        break :x _ref.*;
        \\    });
        \\}
    });

    cases.addC("shift right assign",
        \\int log2(unsigned a) {
        \\    int i = 0;
        \\    while (a > 0) {
        \\        a >>= 1;
        \\    }
        \\    return i;
        \\}
    , &[_][]const u8{
        \\pub export fn log2(_arg_a: c_uint) c_int {
        \\    var a = _arg_a;
        \\    var i: c_int = 0;
        \\    while (a > @as(c_uint, 0)) {
        \\        a >>= @as(@import("std").math.Log2Int(c_uint), 1);
        \\    }
        \\    return i;
        \\}
    });

    cases.addC("shift right assign with a fixed size type",
        \\#include <stdint.h>
        \\int log2(uint32_t a) {
        \\    int i = 0;
        \\    while (a > 0) {
        \\        a >>= 1;
        \\    }
        \\    return i;
        \\}
    , &[_][]const u8{
        \\pub export fn log2(_arg_a: u32) c_int {
        \\    var a = _arg_a;
        \\    var i: c_int = 0;
        \\    while (a > @as(c_uint, 0)) {
        \\        a >>= @as(u5, 1);
        \\    }
        \\    return i;
        \\}
    });

    cases.addC("compound assignment operators",
        \\void foo(void) {
        \\    int a = 0;
        \\    a += (a += 1);
        \\    a -= (a -= 1);
        \\    a *= (a *= 1);
        \\    a &= (a &= 1);
        \\    a |= (a |= 1);
        \\    a ^= (a ^= 1);
        \\    a >>= (a >>= 1);
        \\    a <<= (a <<= 1);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = 0;
        \\    a += (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* + 1);
        \\        break :x _ref.*;
        \\    });
        \\    a -= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* - 1);
        \\        break :x _ref.*;
        \\    });
        \\    a *= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* * 1);
        \\        break :x _ref.*;
        \\    });
        \\    a &= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* & 1);
        \\        break :x _ref.*;
        \\    });
        \\    a |= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* | 1);
        \\        break :x _ref.*;
        \\    });
        \\    a ^= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* ^ 1);
        \\        break :x _ref.*;
        \\    });
        \\    a >>= @as(@import("std").math.Log2Int(c_int), (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* >> @as(@import("std").math.Log2Int(c_int), 1));
        \\        break :x _ref.*;
        \\    }));
        \\    a <<= @as(@import("std").math.Log2Int(c_int), (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* << @as(@import("std").math.Log2Int(c_int), 1));
        \\        break :x _ref.*;
        \\    }));
        \\}
    });

    cases.addC("compound assignment operators unsigned",
        \\void foo(void) {
        \\    unsigned a = 0;
        \\    a += (a += 1);
        \\    a -= (a -= 1);
        \\    a *= (a *= 1);
        \\    a &= (a &= 1);
        \\    a |= (a |= 1);
        \\    a ^= (a ^= 1);
        \\    a >>= (a >>= 1);
        \\    a <<= (a <<= 1);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_uint = @as(c_uint, 0);
        \\    a +%= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* +% @as(c_uint, 1));
        \\        break :x _ref.*;
        \\    });
        \\    a -%= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* -% @as(c_uint, 1));
        \\        break :x _ref.*;
        \\    });
        \\    a *%= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* *% @as(c_uint, 1));
        \\        break :x _ref.*;
        \\    });
        \\    a &= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* & @as(c_uint, 1));
        \\        break :x _ref.*;
        \\    });
        \\    a |= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* | @as(c_uint, 1));
        \\        break :x _ref.*;
        \\    });
        \\    a ^= (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* ^ @as(c_uint, 1));
        \\        break :x _ref.*;
        \\    });
        \\    a >>= @as(@import("std").math.Log2Int(c_uint), (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* >> @as(@import("std").math.Log2Int(c_uint), 1));
        \\        break :x _ref.*;
        \\    }));
        \\    a <<= @as(@import("std").math.Log2Int(c_uint), (x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* << @as(@import("std").math.Log2Int(c_uint), 1));
        \\        break :x _ref.*;
        \\    }));
        \\}
    });

    cases.addC("post increment/decrement",
        \\void foo(void) {
        \\    int i = 0;
        \\    unsigned u = 0;
        \\    i++;
        \\    i--;
        \\    u++;
        \\    u--;
        \\    i = i++;
        \\    i = i--;
        \\    u = u++;
        \\    u = u--;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var i: c_int = 0;
        \\    var u: c_uint = @as(c_uint, 0);
        \\    i += 1;
        \\    i -= 1;
        \\    u +%= 1;
        \\    u -%= 1;
        \\    i = (x: {
        \\        const _ref = &i;
        \\        const _tmp = _ref.*;
        \\        _ref.* += 1;
        \\        break :x _tmp;
        \\    });
        \\    i = (x: {
        \\        const _ref = &i;
        \\        const _tmp = _ref.*;
        \\        _ref.* -= 1;
        \\        break :x _tmp;
        \\    });
        \\    u = (x: {
        \\        const _ref = &u;
        \\        const _tmp = _ref.*;
        \\        _ref.* +%= 1;
        \\        break :x _tmp;
        \\    });
        \\    u = (x: {
        \\        const _ref = &u;
        \\        const _tmp = _ref.*;
        \\        _ref.* -%= 1;
        \\        break :x _tmp;
        \\    });
        \\}
    });

    cases.addC("implicit casts",
        \\#include <stdbool.h>
        \\
        \\void fn_int(int x);
        \\void fn_f32(float x);
        \\void fn_f64(double x);
        \\void fn_char(char x);
        \\void fn_bool(bool x);
        \\void fn_ptr(void *x);
        \\
        \\void call(int q) {
        \\    fn_int(3.0f);
        \\    fn_int(3.0);
        \\    fn_int(3.0L);
        \\    fn_int('ABCD');
        \\    fn_f32(3);
        \\    fn_f64(3);
        \\    fn_char('3');
        \\    fn_char('\x1');
        \\    fn_char(0);
        \\    fn_f32(3.0f);
        \\    fn_f64(3.0);
        \\    fn_bool(123);
        \\    fn_bool(0);
        \\    fn_bool(&fn_int);
        \\    fn_int(&fn_int);
        \\    fn_ptr(42);
        \\}
    , &[_][]const u8{
        \\pub extern fn fn_int(x: c_int) void;
        \\pub extern fn fn_f32(x: f32) void;
        \\pub extern fn fn_f64(x: f64) void;
        \\pub extern fn fn_char(x: u8) void;
        \\pub extern fn fn_bool(x: bool) void;
        \\pub extern fn fn_ptr(x: ?*c_void) void;
        \\pub export fn call(q: c_int) void {
        \\    fn_int(@floatToInt(c_int, 3.000000));
        \\    fn_int(@floatToInt(c_int, 3.000000));
        \\    fn_int(@floatToInt(c_int, 3.000000));
        \\    fn_int(1094861636);
        \\    fn_f32(@intToFloat(f32, 3));
        \\    fn_f64(@intToFloat(f64, 3));
        \\    fn_char(@as(u8, '3'));
        \\    fn_char(@as(u8, '\x01'));
        \\    fn_char(@as(u8, 0));
        \\    fn_f32(3.000000);
        \\    fn_f64(3.000000);
        \\    fn_bool(true);
        \\    fn_bool(false);
        \\    fn_bool(@ptrToInt(&fn_int) != 0);
        \\    fn_int(@intCast(c_int, @ptrToInt(&fn_int)));
        \\    fn_ptr(@intToPtr(?*c_void, 42));
        \\}
    });

    cases.addC("function call",
        \\static void bar(void) { }
        \\void foo(int *(baz)(void)) {
        \\    bar();
        \\    baz();
        \\}
    , &[_][]const u8{
        \\pub fn bar() void {}
        \\pub export fn foo(baz: ?extern fn () [*c]c_int) void {
        \\    bar();
        \\    _ = baz.?();
        \\}
    });

    cases.add("macro defines string literal with hex",
        \\#define FOO "aoeu\xab derp"
        \\#define FOO2 "aoeu\x0007a derp"
        \\#define FOO_CHAR '\xfF'
    , &[_][]const u8{
        \\pub const FOO = "aoeu\xab derp";
    ,
        \\pub const FOO2 = "aoeuz derp";
    ,
        \\pub const FOO_CHAR = 255;
    });

    cases.add("macro defines string literal with octal",
        \\#define FOO "aoeu\023 derp"
        \\#define FOO2 "aoeu\0234 derp"
        \\#define FOO_CHAR '\077'
    , &[_][]const u8{
        \\pub const FOO = "aoeu\x13 derp";
    ,
        \\pub const FOO2 = "aoeu\x134 derp";
    ,
        \\pub const FOO_CHAR = 63;
    });

    cases.add("enums",
        \\enum Foo {
        \\    FooA,
        \\    FooB,
        \\    Foo1,
        \\};
    , &[_][]const u8{
        \\pub const enum_Foo = extern enum {
        \\    A,
        \\    B,
        \\    @"1",
        \\};
    ,
        \\pub const FooA = enum_Foo.A;
    ,
        \\pub const FooB = enum_Foo.B;
    ,
        \\pub const Foo1 = enum_Foo.@"1";
    ,
        \\pub const Foo = enum_Foo;
    });

    cases.add("enums",
        \\enum Foo {
        \\    FooA = 2,
        \\    FooB = 5,
        \\    Foo1,
        \\};
    , &[_][]const u8{
        \\pub const enum_Foo = extern enum {
        \\    A = 2,
        \\    B = 5,
        \\    @"1" = 6,
        \\};
    ,
        \\pub const FooA = enum_Foo.A;
    ,
        \\pub const FooB = enum_Foo.B;
    ,
        \\pub const Foo1 = enum_Foo.@"1";
    ,
        \\pub const Foo = enum_Foo;
    });
}
