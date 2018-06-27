const tests = @import("tests.zig");

pub fn addCases(cases: *tests.TranslateCContext) void {
    cases.add("double define struct",
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
    ,
        \\pub const struct_Foo = extern struct {
        \\    a: ?[*]Foo,
        \\};
        \\pub const Foo = struct_Foo;
        \\pub const struct_Bar = extern struct {
        \\    a: ?[*]Foo,
        \\};
    );

    cases.addAllowWarnings("simple data types",
        \\#include <stdint.h>
        \\int foo(char a, unsigned char b, signed char c);
        \\int foo(char a, unsigned char b, signed char c); // test a duplicate prototype
        \\void bar(uint8_t a, uint16_t b, uint32_t c, uint64_t d);
        \\void baz(int8_t a, int16_t b, int32_t c, int64_t d);
    ,
        \\pub extern fn foo(a: u8, b: u8, c: i8) c_int;
    ,
        \\pub extern fn bar(a: u8, b: u16, c: u32, d: u64) void;
    ,
        \\pub extern fn baz(a: i8, b: i16, c: i32, d: i64) void;
    );

    cases.add("noreturn attribute",
        \\void foo(void) __attribute__((noreturn));
    ,
        \\pub extern fn foo() noreturn;
    );

    cases.addC("simple function",
        \\int abs(int a) {
        \\    return a < 0 ? -a : a;
        \\}
    ,
        \\export fn abs(a: c_int) c_int {
        \\    return if (a < 0) -a else a;
        \\}
    );

    cases.add("enums",
        \\enum Foo {
        \\    FooA,
        \\    FooB,
        \\    Foo1,
        \\};
    ,
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
    );

    cases.add("enums",
        \\enum Foo {
        \\    FooA = 2,
        \\    FooB = 5,
        \\    Foo1,
        \\};
    ,
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
    );

    cases.add("restrict -> noalias",
        \\void foo(void *restrict bar, void *restrict);
    ,
        \\pub extern fn foo(noalias bar: ?*c_void, noalias arg1: ?*c_void) void;
    );

    cases.add("simple struct",
        \\struct Foo {
        \\    int x;
        \\    char *y;
        \\};
    ,
        \\const struct_Foo = extern struct {
        \\    x: c_int,
        \\    y: ?[*]u8,
        \\};
    ,
        \\pub const Foo = struct_Foo;
    );

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
    ,
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
        \\pub extern fn func(a: ?[*]struct_Foo, b: ?[*](?[*]enum_Bar)) void;
    ,
        \\pub const Foo = struct_Foo;
    ,
        \\pub const Bar = enum_Bar;
    );

    cases.add("constant size array",
        \\void func(int array[20]);
    ,
        \\pub extern fn func(array: ?[*]c_int) void;
    );

    cases.add("self referential struct with function pointer",
        \\struct Foo {
        \\    void (*derp)(struct Foo *foo);
        \\};
    ,
        \\pub const struct_Foo = extern struct {
        \\    derp: ?extern fn(?[*]struct_Foo) void,
        \\};
    ,
        \\pub const Foo = struct_Foo;
    );

    cases.add("struct prototype used in func",
        \\struct Foo;
        \\struct Foo *some_func(struct Foo *foo, int x);
    ,
        \\pub const struct_Foo = @OpaqueType();
    ,
        \\pub extern fn some_func(foo: ?*struct_Foo, x: c_int) ?*struct_Foo;
    ,
        \\pub const Foo = struct_Foo;
    );

    cases.add("#define a char literal",
        \\#define A_CHAR  'a'
    ,
        \\pub const A_CHAR = 97;
    );

    cases.add("#define an unsigned integer literal",
        \\#define CHANNEL_COUNT 24
    ,
        \\pub const CHANNEL_COUNT = 24;
    );

    cases.add("#define referencing another #define",
        \\#define THING2 THING1
        \\#define THING1 1234
    ,
        \\pub const THING1 = 1234;
    ,
        \\pub const THING2 = THING1;
    );

    cases.add("variables",
        \\extern int extern_var;
        \\static const int int_var = 13;
    ,
        \\pub extern var extern_var: c_int;
    ,
        \\pub const int_var: c_int = 13;
    );

    cases.add("circular struct definitions",
        \\struct Bar;
        \\
        \\struct Foo {
        \\    struct Bar *next;
        \\};
        \\
        \\struct Bar {
        \\    struct Foo *next;
        \\};
    ,
        \\pub const struct_Bar = extern struct {
        \\    next: ?[*]struct_Foo,
        \\};
    ,
        \\pub const struct_Foo = extern struct {
        \\    next: ?[*]struct_Bar,
        \\};
    );

    cases.add("typedef void",
        \\typedef void Foo;
        \\Foo fun(Foo *a);
    ,
        \\pub const Foo = c_void;
    ,
        \\pub extern fn fun(a: ?*Foo) Foo;
    );

    cases.add("generate inline func for #define global extern fn",
        \\extern void (*fn_ptr)(void);
        \\#define foo fn_ptr
        \\
        \\extern char (*fn_ptr2)(int, float);
        \\#define bar fn_ptr2
    ,
        \\pub extern var fn_ptr: ?extern fn() void;
    ,
        \\pub inline fn foo() void {
        \\    return fn_ptr.?();
        \\}
    ,
        \\pub extern var fn_ptr2: ?extern fn(c_int, f32) u8;
    ,
        \\pub inline fn bar(arg0: c_int, arg1: f32) u8 {
        \\    return fn_ptr2.?(arg0, arg1);
        \\}
    );

    cases.add("#define string",
        \\#define  foo  "a string"
    ,
        \\pub const foo = c"a string";
    );

    cases.add("__cdecl doesn't mess up function pointers",
        \\void foo(void (__cdecl *fn_ptr)(void));
    ,
        \\pub extern fn foo(fn_ptr: ?extern fn() void) void;
    );

    cases.add("comment after integer literal",
        \\#define SDL_INIT_VIDEO 0x00000020  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = 32;
    );

    cases.add("u integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020u  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = c_uint(32);
    );

    cases.add("l integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020l  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = c_long(32);
    );

    cases.add("ul integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ul  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = c_ulong(32);
    );

    cases.add("lu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020lu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = c_ulong(32);
    );

    cases.add("ll integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ll  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = c_longlong(32);
    );

    cases.add("ull integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ull  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = c_ulonglong(32);
    );

    cases.add("llu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020llu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = c_ulonglong(32);
    );

    cases.add("zig keywords in C code",
        \\struct comptime {
        \\    int defer;
        \\};
    ,
        \\pub const struct_comptime = extern struct {
        \\    @"defer": c_int,
        \\};
    ,
        \\pub const @"comptime" = struct_comptime;
    );

    cases.add("macro defines string literal with hex",
        \\#define FOO "aoeu\xab derp"
        \\#define FOO2 "aoeu\x0007a derp"
        \\#define FOO_CHAR '\xfF'
    ,
        \\pub const FOO = c"aoeu\xab derp";
    ,
        \\pub const FOO2 = c"aoeuz derp";
    ,
        \\pub const FOO_CHAR = 255;
    );

    cases.add("macro defines string literal with octal",
        \\#define FOO "aoeu\023 derp"
        \\#define FOO2 "aoeu\0234 derp"
        \\#define FOO_CHAR '\077'
    ,
        \\pub const FOO = c"aoeu\x13 derp";
    ,
        \\pub const FOO2 = c"aoeu\x134 derp";
    ,
        \\pub const FOO_CHAR = 63;
    );

    cases.add("macro with parens around negative number",
        \\#define LUA_GLOBALSINDEX        (-10002)
    ,
        \\pub const LUA_GLOBALSINDEX = -10002;
    );

    cases.addC("post increment",
        \\unsigned foo1(unsigned a) {
        \\    a++;
        \\    return a;
        \\}
        \\int foo2(int a) {
        \\    a++;
        \\    return a;
        \\}
    ,
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
    );

    cases.addC("shift right assign",
        \\int log2(unsigned a) {
        \\    int i = 0;
        \\    while (a > 0) {
        \\        a >>= 1;
        \\    }
        \\    return i;
        \\}
    ,
        \\pub export fn log2(_arg_a: c_uint) c_int {
        \\    var a = _arg_a;
        \\    var i: c_int = 0;
        \\    while (a > c_uint(0)) {
        \\        a >>= @import("std").math.Log2Int(c_uint)(1);
        \\    }
        \\    return i;
        \\}
    );

    cases.addC("if statement",
        \\int max(int a, int b) {
        \\    if (a < b)
        \\        return b;
        \\
        \\    if (a < b)
        \\        return b;
        \\    else
        \\        return a;
        \\}
    ,
        \\pub export fn max(a: c_int, b: c_int) c_int {
        \\    if (a < b) return b;
        \\    if (a < b) return b else return a;
        \\}
    );

    cases.addC("==, !=",
        \\int max(int a, int b) {
        \\    if (a == b)
        \\        return a;
        \\    if (a != b)
        \\        return b;
        \\    return a;
        \\}
    ,
        \\pub export fn max(a: c_int, b: c_int) c_int {
        \\    if (a == b) return a;
        \\    if (a != b) return b;
        \\    return a;
        \\}
    );

    cases.addC("add, sub, mul, div, rem",
        \\int s(int a, int b) {
        \\    int c;
        \\    c = a + b;
        \\    c = a - b;
        \\    c = a * b;
        \\    c = a / b;
        \\    c = a % b;
        \\}
        \\unsigned u(unsigned a, unsigned b) {
        \\    unsigned c;
        \\    c = a + b;
        \\    c = a - b;
        \\    c = a * b;
        \\    c = a / b;
        \\    c = a % b;
        \\}
    ,
        \\pub export fn s(a: c_int, b: c_int) c_int {
        \\    var c: c_int = undefined;
        \\    c = (a + b);
        \\    c = (a - b);
        \\    c = (a * b);
        \\    c = @divTrunc(a, b);
        \\    c = @rem(a, b);
        \\}
        \\pub export fn u(a: c_uint, b: c_uint) c_uint {
        \\    var c: c_uint = undefined;
        \\    c = (a +% b);
        \\    c = (a -% b);
        \\    c = (a *% b);
        \\    c = (a / b);
        \\    c = (a % b);
        \\}
    );

    cases.addC("bitwise binary operators",
        \\int max(int a, int b) {
        \\    return (a & b) ^ (a | b);
        \\}
    ,
        \\pub export fn max(a: c_int, b: c_int) c_int {
        \\    return (a & b) ^ (a | b);
        \\}
    );

    cases.addC("logical and, logical or",
        \\int max(int a, int b) {
        \\    if (a < b || a == b)
        \\        return b;
        \\    if (a >= b && a == b)
        \\        return a;
        \\    return a;
        \\}
    ,
        \\pub export fn max(a: c_int, b: c_int) c_int {
        \\    if ((a < b) or (a == b)) return b;
        \\    if ((a >= b) and (a == b)) return a;
        \\    return a;
        \\}
    );

    cases.addC("logical and, logical or on none bool values",
        \\int and_or_none_bool(int a, float b, void *c) {
        \\    if (a && b) return 0;
        \\    if (b && c) return 1;
        \\    if (a && c) return 2;
        \\    if (a || b) return 3;
        \\    if (b || c) return 4;
        \\    if (a || c) return 5;
        \\    return 6;
        \\}
    ,
        \\pub export fn and_or_none_bool(a: c_int, b: f32, c: ?*c_void) c_int {
        \\    if ((a != 0) and (b != 0)) return 0;
        \\    if ((b != 0) and (c != null)) return 1;
        \\    if ((a != 0) and (c != null)) return 2;
        \\    if ((a != 0) or (b != 0)) return 3;
        \\    if ((b != 0) or (c != null)) return 4;
        \\    if ((a != 0) or (c != null)) return 5;
        \\    return 6;
        \\}
    );

    cases.addC("assign",
        \\int max(int a) {
        \\    int tmp;
        \\    tmp = a;
        \\    a = tmp;
        \\}
    ,
        \\pub export fn max(_arg_a: c_int) c_int {
        \\    var a = _arg_a;
        \\    var tmp: c_int = undefined;
        \\    tmp = a;
        \\    a = tmp;
        \\}
    );

    cases.addC("chaining assign",
        \\void max(int a) {
        \\    int b, c;
        \\    c = b = a;
        \\}
    ,
        \\pub export fn max(a: c_int) void {
        \\    var b: c_int = undefined;
        \\    var c: c_int = undefined;
        \\    c = x: {
        \\        const _tmp = a;
        \\        b = _tmp;
        \\        break :x _tmp;
        \\    };
        \\}
    );

    cases.addC("shift right assign with a fixed size type",
        \\#include <stdint.h>
        \\int log2(uint32_t a) {
        \\    int i = 0;
        \\    while (a > 0) {
        \\        a >>= 1;
        \\    }
        \\    return i;
        \\}
    ,
        \\pub export fn log2(_arg_a: u32) c_int {
        \\    var a = _arg_a;
        \\    var i: c_int = 0;
        \\    while (a > c_uint(0)) {
        \\        a >>= u5(1);
        \\    }
        \\    return i;
        \\}
    );

    cases.add("anonymous enum",
        \\enum {
        \\    One,
        \\    Two,
        \\};
    ,
        \\pub const One = 0;
        \\pub const Two = 1;
    );

    cases.addC("function call",
        \\static void bar(void) { }
        \\static int baz(void) { return 0; }
        \\void foo(void) {
        \\    bar();
        \\    baz();
        \\}
    ,
        \\pub fn bar() void {}
        \\pub fn baz() c_int {
        \\    return 0;
        \\}
        \\pub export fn foo() void {
        \\    bar();
        \\    _ = baz();
        \\}
    );

    cases.addC("field access expression",
        \\struct Foo {
        \\    int field;
        \\};
        \\int read_field(struct Foo *foo) {
        \\    return foo->field;
        \\}
    ,
        \\pub const struct_Foo = extern struct {
        \\    field: c_int,
        \\};
        \\pub export fn read_field(foo: ?[*]struct_Foo) c_int {
        \\    return foo.?.field;
        \\}
    );

    cases.addC("null statements",
        \\void foo(void) {
        \\    ;;;;;
        \\}
    ,
        \\pub export fn foo() void {}
    );

    cases.add("undefined array global",
        \\int array[100];
    ,
        \\pub var array: [100]c_int = undefined;
    );

    cases.addC("array access",
        \\int array[100];
        \\int foo(int index) {
        \\    return array[index];
        \\}
    ,
        \\pub var array: [100]c_int = undefined;
        \\pub export fn foo(index: c_int) c_int {
        \\    return array[index];
        \\}
    );

    cases.addC("c style cast",
        \\int float_to_int(float a) {
        \\    return (int)a;
        \\}
    ,
        \\pub export fn float_to_int(a: f32) c_int {
        \\    return c_int(a);
        \\}
    );

    cases.addC("implicit cast to void *",
        \\void *foo(unsigned short *x) {
        \\    return x;
        \\}
    ,
        \\pub export fn foo(x: ?[*]c_ushort) ?*c_void {
        \\    return @ptrCast(?*c_void, x);
        \\}
    );

    cases.addC("sizeof",
        \\#include <stddef.h>
        \\size_t size_of(void) {
        \\        return sizeof(int);
        \\}
    ,
        \\pub export fn size_of() usize {
        \\    return @sizeOf(c_int);
        \\}
    );

    cases.addC("null pointer implicit cast",
        \\int* foo(void) {
        \\    return 0;
        \\}
    ,
        \\pub export fn foo() ?[*]c_int {
        \\    return null;
        \\}
    );

    cases.addC("comma operator",
        \\int foo(void) {
        \\    return 1, 2;
        \\}
    ,
        \\pub export fn foo() c_int {
        \\    return x: {
        \\        _ = 1;
        \\        break :x 2;
        \\    };
        \\}
    );

    cases.addC("bitshift",
        \\int foo(void) {
        \\    return (1 << 2) >> 1;
        \\}
    ,
        \\pub export fn foo() c_int {
        \\    return (1 << @import("std").math.Log2Int(c_int)(2)) >> @import("std").math.Log2Int(c_int)(1);
        \\}
    );

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
    ,
        \\pub export fn foo() void {
        \\    var a: c_int = 0;
        \\    a += x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* + 1);
        \\        break :x _ref.*;
        \\    };
        \\    a -= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* - 1);
        \\        break :x _ref.*;
        \\    };
        \\    a *= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* * 1);
        \\        break :x _ref.*;
        \\    };
        \\    a &= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* & 1);
        \\        break :x _ref.*;
        \\    };
        \\    a |= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* | 1);
        \\        break :x _ref.*;
        \\    };
        \\    a ^= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* ^ 1);
        \\        break :x _ref.*;
        \\    };
        \\    a >>= @import("std").math.Log2Int(c_int)(x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* >> @import("std").math.Log2Int(c_int)(1));
        \\        break :x _ref.*;
        \\    });
        \\    a <<= @import("std").math.Log2Int(c_int)(x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* << @import("std").math.Log2Int(c_int)(1));
        \\        break :x _ref.*;
        \\    });
        \\}
    );

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
    ,
        \\pub export fn foo() void {
        \\    var a: c_uint = c_uint(0);
        \\    a +%= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* +% c_uint(1));
        \\        break :x _ref.*;
        \\    };
        \\    a -%= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* -% c_uint(1));
        \\        break :x _ref.*;
        \\    };
        \\    a *%= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* *% c_uint(1));
        \\        break :x _ref.*;
        \\    };
        \\    a &= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* & c_uint(1));
        \\        break :x _ref.*;
        \\    };
        \\    a |= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* | c_uint(1));
        \\        break :x _ref.*;
        \\    };
        \\    a ^= x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* ^ c_uint(1));
        \\        break :x _ref.*;
        \\    };
        \\    a >>= @import("std").math.Log2Int(c_uint)(x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* >> @import("std").math.Log2Int(c_uint)(1));
        \\        break :x _ref.*;
        \\    });
        \\    a <<= @import("std").math.Log2Int(c_uint)(x: {
        \\        const _ref = &a;
        \\        _ref.* = (_ref.* << @import("std").math.Log2Int(c_uint)(1));
        \\        break :x _ref.*;
        \\    });
        \\}
    );

    cases.addC("duplicate typedef",
        \\typedef long foo;
        \\typedef int bar;
        \\typedef long foo;
        \\typedef int baz;
    ,
        \\pub const foo = c_long;
        \\pub const bar = c_int;
        \\pub const baz = c_int;
    );

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
    ,
        \\pub export fn foo() void {
        \\    var i: c_int = 0;
        \\    var u: c_uint = c_uint(0);
        \\    i += 1;
        \\    i -= 1;
        \\    u +%= 1;
        \\    u -%= 1;
        \\    i = x: {
        \\        const _ref = &i;
        \\        const _tmp = _ref.*;
        \\        _ref.* += 1;
        \\        break :x _tmp;
        \\    };
        \\    i = x: {
        \\        const _ref = &i;
        \\        const _tmp = _ref.*;
        \\        _ref.* -= 1;
        \\        break :x _tmp;
        \\    };
        \\    u = x: {
        \\        const _ref = &u;
        \\        const _tmp = _ref.*;
        \\        _ref.* +%= 1;
        \\        break :x _tmp;
        \\    };
        \\    u = x: {
        \\        const _ref = &u;
        \\        const _tmp = _ref.*;
        \\        _ref.* -%= 1;
        \\        break :x _tmp;
        \\    };
        \\}
    );

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
    ,
        \\pub export fn foo() void {
        \\    var i: c_int = 0;
        \\    var u: c_uint = c_uint(0);
        \\    i += 1;
        \\    i -= 1;
        \\    u +%= 1;
        \\    u -%= 1;
        \\    i = x: {
        \\        const _ref = &i;
        \\        _ref.* += 1;
        \\        break :x _ref.*;
        \\    };
        \\    i = x: {
        \\        const _ref = &i;
        \\        _ref.* -= 1;
        \\        break :x _ref.*;
        \\    };
        \\    u = x: {
        \\        const _ref = &u;
        \\        _ref.* +%= 1;
        \\        break :x _ref.*;
        \\    };
        \\    u = x: {
        \\        const _ref = &u;
        \\        _ref.* -%= 1;
        \\        break :x _ref.*;
        \\    };
        \\}
    );

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
    ,
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
    );

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
    ,
        \\pub export fn foo() void {}
        \\pub export fn baz() c_int {
        \\    return 0;
        \\}
        \\pub export fn bar() void {
        \\    var f: ?extern fn() void = foo;
        \\    var b: ?extern fn() c_int = baz;
        \\    f.?();
        \\    f.?();
        \\    foo();
        \\    _ = b.?();
        \\    _ = b.?();
        \\    _ = baz();
        \\}
    );

    cases.addC("normal deref",
        \\void foo(int *x) {
        \\    *x = 1;
        \\}
    ,
        \\pub export fn foo(x: ?[*]c_int) void {
        \\    x.?.* = 1;
        \\}
    );

    cases.add("simple union",
        \\union Foo {
        \\    int x;
        \\    double y;
        \\};
    ,
        \\pub const union_Foo = extern union {
        \\    x: c_int,
        \\    y: f64,
        \\};
    ,
        \\pub const Foo = union_Foo;
    );

    cases.add("address of operator",
        \\int foo(void) {
        \\    int x = 1234;
        \\    int *ptr = &x;
        \\    return *ptr;
        \\}
    ,
        \\pub fn foo() c_int {
        \\    var x: c_int = 1234;
        \\    var ptr: ?[*]c_int = &x;
        \\    return ptr.?.*;
        \\}
    );

    cases.add("string literal",
        \\const char *foo(void) {
        \\    return "bar";
        \\}
    ,
        \\pub fn foo() ?[*]const u8 {
        \\    return c"bar";
        \\}
    );

    cases.add("return void",
        \\void foo(void) {
        \\    return;
        \\}
    ,
        \\pub fn foo() void {
        \\    return;
        \\}
    );

    cases.add("for loop",
        \\void foo(void) {
        \\    for (int i = 0; i < 10; i += 1) { }
        \\}
    ,
        \\pub fn foo() void {
        \\    {
        \\        var i: c_int = 0;
        \\        while (i < 10) : (i += 1) {}
        \\    }
        \\}
    );

    cases.add("empty for loop",
        \\void foo(void) {
        \\    for (;;) { }
        \\}
    ,
        \\pub fn foo() void {
        \\    while (true) {}
        \\}
    );

    cases.add("break statement",
        \\void foo(void) {
        \\    for (;;) {
        \\        break;
        \\    }
        \\}
    ,
        \\pub fn foo() void {
        \\    while (true) {
        \\        break;
        \\    }
        \\}
    );

    cases.add("continue statement",
        \\void foo(void) {
        \\    for (;;) {
        \\        continue;
        \\    }
        \\}
    ,
        \\pub fn foo() void {
        \\    while (true) {
        \\        continue;
        \\    }
        \\}
    );

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
    ,
        \\pub const GLbitfield = c_uint;
    ,
        \\pub const PFNGLCLEARPROC = ?extern fn(GLbitfield) void;
    ,
        \\pub const OpenGLProc = ?extern fn() void;
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
    );

    cases.add("variable name shadowing",
        \\int foo(void) {
        \\    int x = 1;
        \\    {
        \\        int x = 2;
        \\        x += 1;
        \\    }
        \\    return x;
        \\}
    ,
        \\pub fn foo() c_int {
        \\    var x: c_int = 1;
        \\    {
        \\        var x_0: c_int = 2;
        \\        x_0 += 1;
        \\    }
        \\    return x;
        \\}
    );

    cases.add("pointer casting",
        \\float *ptrcast(int *a) {
        \\    return (float *)a;
        \\}
    ,
        \\fn ptrcast(a: ?[*]c_int) ?[*]f32 {
        \\    return @ptrCast(?[*]f32, a);
        \\}
    );

    cases.add("bin not",
        \\int foo(int x) {
        \\    return ~x;
        \\}
    ,
        \\pub fn foo(x: c_int) c_int {
        \\    return ~x;
        \\}
    );

    cases.add("bool not",
        \\int foo(int a, float b, void *c) {
        \\    return !(a == 0);
        \\    return !a;
        \\    return !b;
        \\    return !c;
        \\}
    ,
        \\pub fn foo(a: c_int, b: f32, c: ?*c_void) c_int {
        \\    return !(a == 0);
        \\    return !(a != 0);
        \\    return !(b != 0);
        \\    return !(c != null);
        \\}
    );

    cases.add("primitive types included in defined symbols",
        \\int foo(int u32) {
        \\    return u32;
        \\}
    ,
        \\pub fn foo(u32_0: c_int) c_int {
        \\    return u32_0;
        \\}
    );

    cases.add("const ptr initializer",
        \\static const char *v0 = "0.0.0";
    ,
        \\pub var v0: ?[*]const u8 = c"0.0.0";
    );

    cases.add("static incomplete array inside function",
        \\void foo(void) {
        \\    static const char v2[] = "2.2.2";
        \\}
    ,
        \\pub fn foo() void {
        \\    const v2: [*]const u8 = c"2.2.2";
        \\}
    );

    cases.add("macro pointer cast",
        \\#define NRF_GPIO ((NRF_GPIO_Type *) NRF_GPIO_BASE)
    ,
        \\pub const NRF_GPIO = if (@typeId(@typeOf(NRF_GPIO_BASE)) == @import("builtin").TypeId.Pointer) @ptrCast([*]NRF_GPIO_Type, NRF_GPIO_BASE) else if (@typeId(@typeOf(NRF_GPIO_BASE)) == @import("builtin").TypeId.Int) @intToPtr([*]NRF_GPIO_Type, NRF_GPIO_BASE) else ([*]NRF_GPIO_Type)(NRF_GPIO_BASE);
    );

    cases.add("if on none bool",
        \\enum SomeEnum { A, B, C };
        \\int if_none_bool(int a, float b, void *c, enum SomeEnum d) {
        \\    if (a) return 0;
        \\    if (b) return 1;
        \\    if (c) return 2;
        \\    if (d) return 3;
        \\    return 4;
        \\}
    ,
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
        \\    if (d != @bitCast(enum_SomeEnum, @TagType(enum_SomeEnum)(0))) return 3;
        \\    return 4;
        \\}
    );

    cases.add("while on none bool",
        \\int while_none_bool(int a, float b, void *c) {
        \\    while (a) return 0;
        \\    while (b) return 1;
        \\    while (c) return 2;
        \\    return 3;
        \\}
    ,
        \\pub fn while_none_bool(a: c_int, b: f32, c: ?*c_void) c_int {
        \\    while (a != 0) return 0;
        \\    while (b != 0) return 1;
        \\    while (c != null) return 2;
        \\    return 3;
        \\}
    );

    cases.add("for on none bool",
        \\int for_none_bool(int a, float b, void *c) {
        \\    for (;a;) return 0;
        \\    for (;b;) return 1;
        \\    for (;c;) return 2;
        \\    return 3;
        \\}
    ,
        \\pub fn for_none_bool(a: c_int, b: f32, c: ?*c_void) c_int {
        \\    while (a != 0) return 0;
        \\    while (b != 0) return 1;
        \\    while (c != null) return 2;
        \\    return 3;
        \\}
    );

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
    ,
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
    );
}
