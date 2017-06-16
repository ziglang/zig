const tests = @import("tests.zig");

pub fn addCases(cases: &tests.ParseHContext) {
    cases.addAllowWarnings("simple data types",
        \\#include <stdint.h>
        \\int foo(char a, unsigned char b, signed char c);
        \\int foo(char a, unsigned char b, signed char c); // test a duplicate prototype
        \\void bar(uint8_t a, uint16_t b, uint32_t c, uint64_t d);
        \\void baz(int8_t a, int16_t b, int32_t c, int64_t d);
    ,
        \\pub extern fn foo(a: u8, b: u8, c: i8) -> c_int;
    ,
        \\pub extern fn bar(a: u8, b: u16, c: u32, d: u64);
    ,
        \\pub extern fn baz(a: i8, b: i16, c: i32, d: i64);
    );

    cases.add("noreturn attribute",
        \\void foo(void) __attribute__((noreturn));
    ,
        \\pub extern fn foo() -> noreturn;
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
        \\pub const FooA = 0;
    ,
        \\pub const FooB = 1;
    ,
        \\pub const Foo1 = 2;
    ,
        \\pub const Foo = enum_Foo
    );

    cases.add("restrict -> noalias",
        \\void foo(void *restrict bar, void *restrict);
    ,
        \\pub extern fn foo(noalias bar: ?&c_void, noalias arg1: ?&c_void);
    );

    cases.add("simple struct",
        \\struct Foo {
        \\    int x;
        \\    char *y;
        \\};
    ,
        \\const struct_Foo = extern struct {
        \\    x: c_int,
        \\    y: ?&u8,
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
        \\pub const BarA = 0;
    ,
        \\pub const BarB = 1;
    ,
        \\pub extern fn func(a: ?&struct_Foo, b: ?&?&enum_Bar);
    ,
        \\pub const Foo = struct_Foo;
    ,
        \\pub const Bar = enum_Bar;
    );

    cases.add("constant size array",
        \\void func(int array[20]);
    ,
        \\pub extern fn func(array: ?&c_int);
    );

    cases.add("self referential struct with function pointer",
        \\struct Foo {
        \\    void (*derp)(struct Foo *foo);
        \\};
    ,
        \\pub const struct_Foo = extern struct {
        \\    derp: ?extern fn(?&struct_Foo),
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
        \\pub extern fn some_func(foo: ?&struct_Foo, x: c_int) -> ?&struct_Foo;
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
        \\    next: ?&struct_Foo,
        \\};
    ,
        \\pub const struct_Foo = extern struct {
        \\    next: ?&struct_Bar,
        \\};
    );

    cases.add("typedef void",
        \\typedef void Foo;
        \\Foo fun(Foo *a);
    ,
        \\pub const Foo = c_void;
    ,
        \\pub extern fn fun(a: ?&c_void);
    );

    cases.add("generate inline func for #define global extern fn",
        \\extern void (*fn_ptr)(void);
        \\#define foo fn_ptr
        \\
        \\extern char (*fn_ptr2)(int, float);
        \\#define bar fn_ptr2
    ,
        \\pub extern var fn_ptr: ?extern fn();
    ,
        \\pub fn foo();
    ,
        \\pub extern var fn_ptr2: ?extern fn(c_int, f32) -> u8;
    ,
        \\pub fn bar(arg0: c_int, arg1: f32) -> u8;
    );

    cases.add("#define string",
        \\#define  foo  "a string"
    ,
        \\pub const foo: &const u8 = &(c str lit);
    );

    cases.add("__cdecl doesn't mess up function pointers",
        \\void foo(void (__cdecl *fn_ptr)(void));
    ,
        \\pub extern fn foo(fn_ptr: ?extern fn());
    );

    cases.add("comment after integer literal",
        \\#define SDL_INIT_VIDEO 0x00000020  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO = 32;
    );

    cases.add("u integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020u  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO: c_uint = 32;
    );

    cases.add("l integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020l  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO: c_long = 32;
    );

    cases.add("ul integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ul  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO: c_ulong = 32;
    );

    cases.add("lu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020lu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO: c_ulong = 32;
    );

    cases.add("ll integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ll  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO: c_longlong = 32;
    );

    cases.add("ull integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ull  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO: c_ulonglong = 32;
    );

    cases.add("llu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020llu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    ,
        \\pub const SDL_INIT_VIDEO: c_ulonglong = 32;
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

    cases.add("macro defines string literal with octal",
        \\#define FOO "aoeu\023 derp"
        \\#define FOO2 "aoeu\0234 derp"
        \\#define FOO_CHAR '\077'
    ,
        \\pub const FOO: &const u8 = &(c str lit);
    ,
        \\pub const FOO2: &const u8 = &(c str lit);
    ,
        \\pub const FOO_CHAR = 63;
    );
}
