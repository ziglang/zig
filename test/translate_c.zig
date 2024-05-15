const std = @import("std");
const builtin = @import("builtin");
const tests = @import("tests.zig");

// ********************************************************
// *                                                      *
// *               DO NOT ADD NEW CASES HERE              *
// *     instead add a file to test/cases/translate_c     *
// *                                                      *
// ********************************************************

pub fn addCases(cases: *tests.TranslateCContext) void {
    const default_enum_type = if (builtin.abi == .msvc) "c_int" else "c_uint";

    cases.add("do while with breaks",
        \\void foo(int a) {
        \\    do {
        \\        if (a) break;
        \\    } while (4);
        \\    do {
        \\        if (a) break;
        \\    } while (0);
        \\    do {
        \\        if (a) break;
        \\    } while (a);
        \\    do {
        \\        break;
        \\    } while (3);
        \\    do {
        \\        break;
        \\    } while (0);
        \\    do {
        \\        break;
        \\    } while (a);
        \\}
    , &[_][]const u8{
        \\pub export fn foo(arg_a: c_int) void {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    while (true) {
        \\        if (a != 0) break;
        \\    }
        \\    while (true) {
        \\        if (a != 0) break;
        \\        if (!false) break;
        \\    }
        \\    while (true) {
        \\        if (a != 0) break;
        \\        if (!(a != 0)) break;
        \\    }
        \\    while (true) {
        \\        break;
        \\    }
        \\    while (true) {
        \\        break;
        \\    }
        \\    while (true) {
        \\        break;
        \\    }
        \\}
    });

    cases.add("variables check for opaque demotion",
        \\struct A {
        \\    _Atomic int a;
        \\} a;
        \\int main(void) {
        \\    struct A a;
        \\}
    , &[_][]const u8{
        \\pub const struct_A = opaque {};
        \\pub const a = @compileError("non-extern variable has opaque type");
        ,
        \\pub extern fn main() c_int;
    });

    cases.add("unnamed child types of typedef receive typedef's name",
        \\typedef enum {
        \\    FooA,
        \\    FooB,
        \\} Foo;
        \\typedef struct {
        \\    int a, b;
        \\} Bar;
    , &[_][]const u8{
        \\pub const FooA: c_int = 0;
        \\pub const FooB: c_int = 1;
        \\pub const Foo =
        ++ " " ++ default_enum_type ++
            \\;
            \\pub const Bar = extern struct {
            \\    a: c_int = @import("std").mem.zeroes(c_int),
            \\    b: c_int = @import("std").mem.zeroes(c_int),
            \\};
    });

    cases.add("if as while stmt has semicolon",
        \\void foo() {
        \\    while (1) if (1) {
        \\        int a = 1;
        \\    } else {
        \\        int b = 2;
        \\    }
        \\    if (1) if (1) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    while (true) if (true) {
        \\        var a: c_int = 1;
        \\        _ = &a;
        \\    } else {
        \\        var b: c_int = 2;
        \\        _ = &b;
        \\    };
        \\    if (true) if (true) {};
        \\}
    });

    cases.add("conditional operator cast to void",
        \\int bar();
        \\void foo() {
        \\    int a;
        \\    a ? a = 2 : bar();
        \\}
    , &[_][]const u8{
        \\pub extern fn bar(...) c_int;
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    _ = &a;
        \\    if (a != 0) a = 2 else _ = bar();
        \\}
    });

    cases.add("scoped typedef",
        \\void foo() {
        \\	typedef union {
        \\		int A;
        \\		int B;
        \\		int C;
        \\	} Foo;
        \\	Foo a = {0};
        \\	{
        \\		typedef union {
        \\			int A;
        \\			int B;
        \\			int C;
        \\		} Foo;
        \\		Foo a = {0};
        \\	}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    const union_unnamed_1 = extern union {
        \\        A: c_int,
        \\        B: c_int,
        \\        C: c_int,
        \\    };
        \\    _ = &union_unnamed_1;
        \\    const Foo = union_unnamed_1;
        \\    _ = &Foo;
        \\    var a: Foo = Foo{
        \\        .A = @as(c_int, 0),
        \\    };
        \\    _ = &a;
        \\    {
        \\        const union_unnamed_2 = extern union {
        \\            A: c_int,
        \\            B: c_int,
        \\            C: c_int,
        \\        };
        \\        _ = &union_unnamed_2;
        \\        const Foo_1 = union_unnamed_2;
        \\        _ = &Foo_1;
        \\        var a_2: Foo_1 = Foo_1{
        \\            .A = @as(c_int, 0),
        \\        };
        \\        _ = &a_2;
        \\    }
        \\}
    });

    cases.add("use cast param as macro fn return type",
        \\#include <stdint.h>
        \\#define SYS_BASE_CACHED 0
        \\#define MEM_PHYSICAL_TO_K0(x) (void*)((uint32_t)(x) + SYS_BASE_CACHED)
    , &[_][]const u8{
        \\pub inline fn MEM_PHYSICAL_TO_K0(x: anytype) ?*anyopaque {
        \\    _ = &x;
        \\    return @import("std").zig.c_translation.cast(?*anyopaque, @import("std").zig.c_translation.cast(u32, x) + SYS_BASE_CACHED);
        \\}
    });

    cases.add("variadic function demoted to extern",
        \\int foo(int bar, ...) {
        \\    return 1;
        \\}
    , &[_][]const u8{
        \\warning: TODO unable to translate variadic function, demoted to extern
        \\pub extern fn foo(bar: c_int, ...) c_int;
    });

    cases.add("pointer to opaque demoted struct",
        \\typedef struct {
        \\    _Atomic int foo;
        \\} Foo;
        \\
        \\typedef struct {
        \\    Foo *bar;
        \\} Bar;
    , &[_][]const u8{
        \\source.h:1:9: warning: struct demoted to opaque type - unable to translate type of field foo
        \\pub const Foo = opaque {};
        \\pub const Bar = extern struct {
        \\    bar: ?*Foo = @import("std").mem.zeroes(?*Foo),
        \\};
    });

    cases.add("macro expressions respect C operator precedence",
        \\int *foo = 0;
        \\#define FOO *((foo) + 2)
        \\#define VALUE  (1 + 2 * 3 + 4 * 5 + 6 << 7 | 8 == 9)
        \\#define _AL_READ3BYTES(p)   ((*(unsigned char *)(p))            \
        \\                             | (*((unsigned char *)(p) + 1) << 8)  \
        \\                             | (*((unsigned char *)(p) + 2) << 16))
    , &[_][]const u8{
        \\pub const FOO = (foo + @as(c_int, 2)).*;
        ,
        \\pub const VALUE = ((((@as(c_int, 1) + (@as(c_int, 2) * @as(c_int, 3))) + (@as(c_int, 4) * @as(c_int, 5))) + @as(c_int, 6)) << @as(c_int, 7)) | @intFromBool(@as(c_int, 8) == @as(c_int, 9));
        ,
        \\pub inline fn _AL_READ3BYTES(p: anytype) @TypeOf((@import("std").zig.c_translation.cast([*c]u8, p).* | ((@import("std").zig.c_translation.cast([*c]u8, p) + @as(c_int, 1)).* << @as(c_int, 8))) | ((@import("std").zig.c_translation.cast([*c]u8, p) + @as(c_int, 2)).* << @as(c_int, 16))) {
        \\    _ = &p;
        \\    return (@import("std").zig.c_translation.cast([*c]u8, p).* | ((@import("std").zig.c_translation.cast([*c]u8, p) + @as(c_int, 1)).* << @as(c_int, 8))) | ((@import("std").zig.c_translation.cast([*c]u8, p) + @as(c_int, 2)).* << @as(c_int, 16));
        \\}
    });

    cases.add("static variable in block scope",
        \\float bar;
        \\int foo() {
        \\    _Thread_local static int bar = 2;
        \\}
    , &[_][]const u8{
        \\pub export var bar: f32 = @import("std").mem.zeroes(f32);
        \\pub export fn foo() c_int {
        \\    const bar_1 = struct {
        \\        threadlocal var static: c_int = 2;
        \\    };
        \\    _ = &bar_1;
        \\    return 0;
        \\}
    });

    cases.add("missing return stmt",
        \\int foo() {}
        \\int bar() {
        \\    int a = 2;
        \\}
        \\int baz() {
        \\    return 0;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return 0;
        \\}
        \\pub export fn bar() c_int {
        \\    var a: c_int = 2;
        \\    _ = &a;
        \\    return 0;
        \\}
        \\pub export fn baz() c_int {
        \\    return 0;
        \\}
    });

    cases.add("alignof",
        \\void main() {
        \\    int a = _Alignof(int);
        \\}
    , &[_][]const u8{
        \\pub export fn main() void {
        \\    var a: c_int = @as(c_int, @bitCast(@as(c_uint, @truncate(@alignOf(c_int)))));
        \\    _ = &a;
        \\}
    });

    cases.add("initializer list macro",
        \\typedef struct Color {
        \\    unsigned char r;
        \\    unsigned char g;
        \\    unsigned char b;
        \\    unsigned char a;
        \\} Color;
        \\#define CLITERAL(type)      (type)
        \\#define LIGHTGRAY  CLITERAL(Color){ 200, 200, 200, 255 }   // Light Gray
        \\typedef struct boom_t
        \\{
        \\    int i1;
        \\} boom_t;
        \\#define FOO ((boom_t){1})
        \\typedef struct { float x; } MyCStruct;
        \\#define A(_x)   (MyCStruct) { .x = (_x) }
        \\#define B A(0.f)
    , &[_][]const u8{
        \\pub const struct_Color = extern struct {
        \\    r: u8 = @import("std").mem.zeroes(u8),
        \\    g: u8 = @import("std").mem.zeroes(u8),
        \\    b: u8 = @import("std").mem.zeroes(u8),
        \\    a: u8 = @import("std").mem.zeroes(u8),
        \\};
        \\pub const Color = struct_Color;
        ,
        \\pub inline fn CLITERAL(@"type": anytype) @TypeOf(@"type") {
        \\    _ = &@"type";
        \\    return @"type";
        \\}
        ,
        \\pub const LIGHTGRAY = @import("std").mem.zeroInit(CLITERAL(Color), .{ @as(c_int, 200), @as(c_int, 200), @as(c_int, 200), @as(c_int, 255) });
        ,
        \\pub const struct_boom_t = extern struct {
        \\    i1: c_int = @import("std").mem.zeroes(c_int),
        \\};
        \\pub const boom_t = struct_boom_t;
        ,
        \\pub const FOO = @import("std").mem.zeroInit(boom_t, .{@as(c_int, 1)});
        ,
        \\pub const MyCStruct = extern struct {
        \\    x: f32 = @import("std").mem.zeroes(f32),
        \\};
        ,
        \\pub inline fn A(_x: anytype) MyCStruct {
        \\    _ = &_x;
        \\    return @import("std").mem.zeroInit(MyCStruct, .{
        \\        .x = _x,
        \\    });
        \\}
        ,
        \\pub const B = A(@as(f32, 0));
    });

    cases.add("complex switch",
        \\int main() {
        \\    int i = 2;
        \\    switch (i) {
        \\        case 0: {
        \\            case 2:{
        \\                i += 2;}
        \\            i += 1;
        \\        }
        \\    }
        \\}
    , &[_][]const u8{ // TODO properly translate this
        \\source.h:5:13: warning: TODO complex switch
        ,
        \\source.h:1:5: warning: unable to translate function, demoted to extern
        \\pub extern fn main() c_int;
    });

    cases.add("correct semicolon after infixop",
        \\#define _IO_ERR_SEEN 0
        \\#define __ferror_unlocked_body(_fp) (((_fp)->_flags & _IO_ERR_SEEN) != 0)
    , &[_][]const u8{
        \\pub inline fn __ferror_unlocked_body(_fp: anytype) @TypeOf((_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0)) {
        \\    _ = &_fp;
        \\    return (_fp.*._flags & _IO_ERR_SEEN) != @as(c_int, 0);
        \\}
    });

    cases.add("c booleans are just ints",
        \\#define FOO(x) ((x >= 0) + (x >= 0))
        \\#define BAR 1 && 2 > 4
    , &[_][]const u8{
        \\pub inline fn FOO(x: anytype) @TypeOf(@intFromBool(x >= @as(c_int, 0)) + @intFromBool(x >= @as(c_int, 0))) {
        \\    _ = &x;
        \\    return @intFromBool(x >= @as(c_int, 0)) + @intFromBool(x >= @as(c_int, 0));
        \\}
        ,
        \\pub const BAR = (@as(c_int, 1) != 0) and (@as(c_int, 2) > @as(c_int, 4));
    });

    cases.add("struct with flexible array",
        \\struct foo { int x; int y[]; };
        \\struct bar { int x; int y[0]; };
    , &[_][]const u8{
        \\pub const struct_foo = extern struct {
        \\    x: c_int align(4) = @import("std").mem.zeroes(c_int),
        \\    pub fn y(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), c_int) {
        \\        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        \\        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), c_int);
        \\        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 4)));
        \\    }
        \\};
        \\pub const struct_bar = extern struct {
        \\    x: c_int align(4) = @import("std").mem.zeroes(c_int),
        \\    pub fn y(self: anytype) @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), c_int) {
        \\        const Intermediate = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), u8);
        \\        const ReturnType = @import("std").zig.c_translation.FlexibleArrayType(@TypeOf(self), c_int);
        \\        return @as(ReturnType, @ptrCast(@alignCast(@as(Intermediate, @ptrCast(self)) + 4)));
        \\    }
        \\};
    });

    cases.add("nested loops without blocks",
        \\void foo() {
        \\    while (0) while (0) {}
        \\    for (;;) while (0);
        \\    for (;;) do {} while (0);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    while (false) while (false) {};
        \\    while (true) while (false) {};
        \\    while (true) while (true) {
        \\        if (!false) break;
        \\    };
        \\}
    });

    cases.add("macro comma operator",
        \\#define foo (foo, bar)
        \\int baz(int x, int y) { return 0; }
        \\#define bar(x) (&x, +3, 4 == 4, 5 * 6, baz(1, 2), 2 % 2, baz(1,2))
    , &[_][]const u8{
        \\pub const foo = blk_1: {
        \\    _ = &foo;
        \\    break :blk_1 bar;
        \\};
        ,
        \\pub inline fn bar(x: anytype) @TypeOf(baz(@as(c_int, 1), @as(c_int, 2))) {
        \\    _ = &x;
        \\    return blk_1: {
        \\        _ = &x;
        \\        _ = @as(c_int, 3);
        \\        _ = @as(c_int, 4) == @as(c_int, 4);
        \\        _ = @as(c_int, 5) * @as(c_int, 6);
        \\        _ = baz(@as(c_int, 1), @as(c_int, 2));
        \\        _ = @import("std").zig.c_translation.MacroArithmetic.rem(@as(c_int, 2), @as(c_int, 2));
        \\        break :blk_1 baz(@as(c_int, 1), @as(c_int, 2));
        \\    };
        \\}
    });

    cases.add("macro keyword define",
        \\#define foo 1
        \\#define inline 2
    , &[_][]const u8{
        \\pub const foo = @as(c_int, 1);
        ,
        \\pub const @"inline" = @as(c_int, 2);
    });

    cases.add("macro line continuation",
        \\int BAR = 0;
        \\#define FOO -\
        \\BAR
    , &[_][]const u8{
        \\pub const FOO = -BAR;
    });

    cases.add("struct with atomic field",
        \\struct arcan_shmif_cont {
        \\        struct arcan_shmif_page* addr;
        \\};
        \\struct arcan_shmif_page {
        \\        volatile _Atomic int abufused[12];
        \\};
    , &[_][]const u8{
        \\source.h:4:8: warning: struct demoted to opaque type - unable to translate type of field abufused
        \\pub const struct_arcan_shmif_page = opaque {};
        \\pub const struct_arcan_shmif_cont = extern struct {
        \\    addr: ?*struct_arcan_shmif_page = @import("std").mem.zeroes(?*struct_arcan_shmif_page),
        \\};
    });

    cases.add("function prototype translated as optional",
        \\typedef void (*fnptr_ty)(void);
        \\typedef __attribute__((cdecl)) void (*fnptr_attr_ty)(void);
        \\struct foo {
        \\    __attribute__((cdecl)) void (*foo)(void);
        \\    void (*bar)(void);
        \\    fnptr_ty baz;
        \\    fnptr_attr_ty qux;
        \\};
    , &[_][]const u8{
        \\pub const fnptr_ty = ?*const fn () callconv(.C) void;
        \\pub const fnptr_attr_ty = ?*const fn () callconv(.C) void;
        \\pub const struct_foo = extern struct {
        \\    foo: ?*const fn () callconv(.C) void = @import("std").mem.zeroes(?*const fn () callconv(.C) void),
        \\    bar: ?*const fn () callconv(.C) void = @import("std").mem.zeroes(?*const fn () callconv(.C) void),
        \\    baz: fnptr_ty = @import("std").mem.zeroes(fnptr_ty),
        \\    qux: fnptr_attr_ty = @import("std").mem.zeroes(fnptr_attr_ty),
        \\};
    });

    cases.add("function prototype with parenthesis",
        \\void (f0) (void *L);
        \\void ((f1)) (void *L);
        \\void (((f2))) (void *L);
    , &[_][]const u8{
        \\pub extern fn f0(L: ?*anyopaque) void;
        \\pub extern fn f1(L: ?*anyopaque) void;
        \\pub extern fn f2(L: ?*anyopaque) void;
    });

    cases.add("array initializer w/ typedef",
        \\typedef unsigned char uuid_t[16];
        \\static const uuid_t UUID_NULL __attribute__ ((unused)) = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    , &[_][]const u8{
        \\pub const uuid_t = [16]u8;
        \\pub const UUID_NULL: uuid_t = [16]u8{
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\    0,
        \\};
    });

    cases.add("empty declaration",
        \\;
    , &[_][]const u8{""});

    cases.add("#define hex literal with capital X",
        \\#define VAL 0XF00D
    , &[_][]const u8{
        \\pub const VAL = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xF00D, .hex);
    });

    cases.add("anonymous struct & unions",
        \\typedef struct {
        \\    union {
        \\        char x;
        \\        struct { int y; };
        \\    };
        \\} outer;
        \\void foo(outer *x) { x->y = x->x; }
    , &[_][]const u8{
        \\const struct_unnamed_2 = extern struct {
        \\    y: c_int = @import("std").mem.zeroes(c_int),
        \\};
        \\const union_unnamed_1 = extern union {
        \\    x: u8,
        \\    unnamed_0: struct_unnamed_2,
        \\};
        \\pub const outer = extern struct {
        \\    unnamed_0: union_unnamed_1 = @import("std").mem.zeroes(union_unnamed_1),
        \\};
        \\pub export fn foo(arg_x: [*c]outer) void {
        \\    var x = arg_x;
        \\    _ = &x;
        \\    x.*.unnamed_0.unnamed_0.y = @as(c_int, @bitCast(@as(c_uint, x.*.unnamed_0.x)));
        \\}
    });

    cases.add("struct initializer - simple",
        \\typedef struct { int x; } foo;
        \\struct {double x,y,z;} s0 = {1.2, 1.3};
        \\struct {int sec,min,hour,day,mon,year;} s1 = {.day=31,12,2014,.sec=30,15,17};
        \\struct {int x,y;} s2 = {.y = 2, .x=1};
        \\foo s3 = { 123 };
    , &[_][]const u8{
        \\pub const foo = extern struct {
        \\    x: c_int = @import("std").mem.zeroes(c_int),
        \\};
        \\const struct_unnamed_1 = extern struct {
        \\    x: f64 = @import("std").mem.zeroes(f64),
        \\    y: f64 = @import("std").mem.zeroes(f64),
        \\    z: f64 = @import("std").mem.zeroes(f64),
        \\};
        \\pub export var s0: struct_unnamed_1 = struct_unnamed_1{
        \\    .x = 1.2,
        \\    .y = 1.3,
        \\    .z = 0,
        \\};
        \\const struct_unnamed_2 = extern struct {
        \\    sec: c_int = @import("std").mem.zeroes(c_int),
        \\    min: c_int = @import("std").mem.zeroes(c_int),
        \\    hour: c_int = @import("std").mem.zeroes(c_int),
        \\    day: c_int = @import("std").mem.zeroes(c_int),
        \\    mon: c_int = @import("std").mem.zeroes(c_int),
        \\    year: c_int = @import("std").mem.zeroes(c_int),
        \\};
        \\pub export var s1: struct_unnamed_2 = struct_unnamed_2{
        \\    .sec = @as(c_int, 30),
        \\    .min = @as(c_int, 15),
        \\    .hour = @as(c_int, 17),
        \\    .day = @as(c_int, 31),
        \\    .mon = @as(c_int, 12),
        \\    .year = @as(c_int, 2014),
        \\};
        \\const struct_unnamed_3 = extern struct {
        \\    x: c_int = @import("std").mem.zeroes(c_int),
        \\    y: c_int = @import("std").mem.zeroes(c_int),
        \\};
        \\pub export var s2: struct_unnamed_3 = struct_unnamed_3{
        \\    .x = @as(c_int, 1),
        \\    .y = @as(c_int, 2),
        \\};
        \\pub export var s3: foo = foo{
        \\    .x = @as(c_int, 123),
        \\};
    });

    cases.add("simple ptrCast for casts between opaque types",
        \\struct opaque;
        \\struct opaque_2;
        \\void function(struct opaque *opaque) {
        \\    struct opaque_2 *cast = (struct opaque_2 *)opaque;
        \\}
    , &[_][]const u8{
        \\pub const struct_opaque = opaque {};
        \\pub const struct_opaque_2 = opaque {};
        \\pub export fn function(arg_opaque_1: ?*struct_opaque) void {
        \\    var opaque_1 = arg_opaque_1;
        \\    _ = &opaque_1;
        \\    var cast: ?*struct_opaque_2 = @as(?*struct_opaque_2, @ptrCast(opaque_1));
        \\    _ = &cast;
        \\}
    });

    cases.add("struct initializer - packed",
        \\struct {int x,y,z;} __attribute__((packed)) s0 = {1, 2};
    , &[_][]const u8{
        \\const struct_unnamed_1 = extern struct {
        \\    x: c_int align(1) = @import("std").mem.zeroes(c_int),
        \\    y: c_int align(1) = @import("std").mem.zeroes(c_int),
        \\    z: c_int align(1) = @import("std").mem.zeroes(c_int),
        \\};
        \\pub export var s0: struct_unnamed_1 = struct_unnamed_1{
        \\    .x = @as(c_int, 1),
        \\    .y = @as(c_int, 2),
        \\    .z = 0,
        \\};
    });

    cases.add("linksection() attribute",
        \\// Use the "segment,section" format to make this test pass when
        \\// targeting the mach-o binary format
        \\__attribute__ ((__section__("NEAR,.data")))
        \\extern char my_array[16];
        \\__attribute__ ((__section__("NEAR,.data")))
        \\void my_fn(void) { }
    , &[_][]const u8{
        \\pub extern var my_array: [16]u8 linksection("NEAR,.data");
        \\pub export fn my_fn() linksection("NEAR,.data") void {}
    });

    cases.add("simple function prototypes",
        \\void __attribute__((noreturn)) foo(void);
        \\int bar(void);
    , &[_][]const u8{
        \\pub extern fn foo() noreturn;
        \\pub extern fn bar() c_int;
    });

    cases.add("simple var decls",
        \\void foo(void) {
        \\    int a;
        \\    char b = 123;
        \\    const int c;
        \\    const unsigned d = 440;
        \\    int e = 10;
        \\    unsigned int f = 10u;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    _ = &a;
        \\    var b: u8 = 123;
        \\    _ = &b;
        \\    const c: c_int = undefined;
        \\    _ = &c;
        \\    const d: c_uint = @as(c_uint, @bitCast(@as(c_int, 440)));
        \\    _ = &d;
        \\    var e: c_int = 10;
        \\    _ = &e;
        \\    var f: c_uint = 10;
        \\    _ = &f;
        \\}
    });

    cases.add("ignore result, explicit function arguments",
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
        \\    _ = &a;
        \\    _ = @as(c_int, 1);
        \\    _ = "hey";
        \\    _ = @as(c_int, 1) + @as(c_int, 1);
        \\    _ = @as(c_int, 1) - @as(c_int, 1);
        \\    a = 1;
        \\}
    });

    cases.add("function with no prototype",
        \\int foo() {
        \\    return 5;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return 5;
        \\}
    });

    cases.add("variables",
        \\extern int extern_var;
        \\static const int int_var = 13;
        \\int foo;
    , &[_][]const u8{
        \\pub extern var extern_var: c_int;
        \\pub const int_var: c_int = 13;
        \\pub export var foo: c_int = @import("std").mem.zeroes(c_int);
    });

    cases.add("const ptr initializer",
        \\static const char *v0 = "0.0.0";
    , &[_][]const u8{
        \\pub var v0: [*c]const u8 = "0.0.0";
    });

    cases.add("static incomplete array inside function",
        \\void foo(void) {
        \\    static const char v2[] = "2.2.2";
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    const v2 = struct {
        \\        const static: [5:0]u8 = "2.2.2".*;
        \\    };
        \\    _ = &v2;
        \\}
    });

    cases.add("simple function definition",
        \\void foo(void) {}
        \\static void bar(void) {}
    , &[_][]const u8{
        \\pub export fn foo() void {}
        \\pub fn bar() callconv(.C) void {}
    });

    cases.add("typedef void",
        \\typedef void Foo;
        \\Foo fun(Foo *a);
    , &[_][]const u8{
        \\pub const Foo = anyopaque;
        ,
        \\pub extern fn fun(a: ?*Foo) void;
    });

    cases.add("duplicate typedef",
        \\typedef long foo;
        \\typedef int bar;
        \\typedef long foo;
        \\typedef int baz;
    , &[_][]const u8{
        \\pub const foo = c_long;
        \\pub const bar = c_int;
        \\pub const baz = c_int;
    });

    cases.add("casting pointers to ints and ints to pointers",
        \\void foo(void);
        \\void bar(void) {
        \\    void *func_ptr = foo;
        \\    void (*typed_func_ptr)(void) = (void (*)(void)) (unsigned long) func_ptr;
        \\}
    , &[_][]const u8{
        \\pub extern fn foo() void;
        \\pub export fn bar() void {
        \\    var func_ptr: ?*anyopaque = @as(?*anyopaque, @ptrCast(&foo));
        \\    _ = &func_ptr;
        \\    var typed_func_ptr: ?*const fn () callconv(.C) void = @as(?*const fn () callconv(.C) void, @ptrFromInt(@as(c_ulong, @intCast(@intFromPtr(func_ptr)))));
        \\    _ = &typed_func_ptr;
        \\}
    });

    cases.add("noreturn attribute",
        \\void foo(void) __attribute__((noreturn));
    , &[_][]const u8{
        \\pub extern fn foo() noreturn;
    });

    cases.add("always_inline attribute",
        \\__attribute__((always_inline)) int foo() {
        \\    return 5;
        \\}
    , &[_][]const u8{
        \\pub inline fn foo() c_int {
        \\    return 5;
        \\}
    });

    cases.add("add, sub, mul, div, rem",
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
        \\    _ = &a;
        \\    var b: c_int = undefined;
        \\    _ = &b;
        \\    var c: c_int = undefined;
        \\    _ = &c;
        \\    c = a + b;
        \\    c = a - b;
        \\    c = a * b;
        \\    c = @divTrunc(a, b);
        \\    c = @import("std").zig.c_translation.signedRemainder(a, b);
        \\    return 0;
        \\}
        \\pub export fn u() c_uint {
        \\    var a: c_uint = undefined;
        \\    _ = &a;
        \\    var b: c_uint = undefined;
        \\    _ = &b;
        \\    var c: c_uint = undefined;
        \\    _ = &c;
        \\    c = a +% b;
        \\    c = a -% b;
        \\    c = a *% b;
        \\    c = a / b;
        \\    c = a % b;
        \\    return 0;
        \\}
    });

    cases.add("typedef of function in struct field",
        \\typedef void lws_callback_function(void);
        \\struct Foo {
        \\    void (*func)(void);
        \\    lws_callback_function *callback_http;
        \\};
    , &[_][]const u8{
        \\pub const lws_callback_function = fn () callconv(.C) void;
        \\pub const struct_Foo = extern struct {
        \\    func: ?*const fn () callconv(.C) void = @import("std").mem.zeroes(?*const fn () callconv(.C) void),
        \\    callback_http: ?*const lws_callback_function = @import("std").mem.zeroes(?*const lws_callback_function),
        \\};
    });

    cases.add("macro with left shift",
        \\#define REDISMODULE_READ (1<<0)
    , &[_][]const u8{
        \\pub const REDISMODULE_READ = @as(c_int, 1) << @as(c_int, 0);
    });

    cases.add("macro with right shift",
        \\#define FLASH_SIZE         0x200000UL          /* 2 MB   */
        \\#define FLASH_BANK_SIZE    (FLASH_SIZE >> 1)   /* 1 MB   */
    , &[_][]const u8{
        \\pub const FLASH_SIZE = @as(c_ulong, 0x200000);
        ,
        \\pub const FLASH_BANK_SIZE = FLASH_SIZE >> @as(c_int, 1);
    });

    cases.add("self referential struct with function pointer",
        \\struct Foo {
        \\    void (*derp)(struct Foo *foo);
        \\};
    , &[_][]const u8{
        \\pub const struct_Foo = extern struct {
        \\    derp: ?*const fn ([*c]struct_Foo) callconv(.C) void = @import("std").mem.zeroes(?*const fn ([*c]struct_Foo) callconv(.C) void),
        \\};
        ,
        \\pub const Foo = struct_Foo;
    });

    cases.add("struct prototype used in func",
        \\struct Foo;
        \\struct Foo *some_func(struct Foo *foo, int x);
    , &[_][]const u8{
        \\pub const struct_Foo = opaque {};
        ,
        \\pub extern fn some_func(foo: ?*struct_Foo, x: c_int) ?*struct_Foo;
        ,
        \\pub const Foo = struct_Foo;
    });

    cases.add("#define an unsigned integer literal",
        \\#define CHANNEL_COUNT 24
    , &[_][]const u8{
        \\pub const CHANNEL_COUNT = @as(c_int, 24);
    });

    cases.add("#define referencing another #define",
        \\#define THING2 THING1
        \\#define THING1 1234
    , &[_][]const u8{
        \\pub const THING1 = @as(c_int, 1234);
        ,
        \\pub const THING2 = THING1;
    });

    cases.add("#define string",
        \\#define  foo  "a string"
    , &[_][]const u8{
        \\pub const foo = "a string";
    });

    cases.add("macro with parens around negative number",
        \\#define LUA_GLOBALSINDEX        (-10002)
    , &[_][]const u8{
        \\pub const LUA_GLOBALSINDEX = -@as(c_int, 10002);
    });

    cases.add(
        "u integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0U",
        &[_][]const u8{
            "pub const ZERO = @as(c_uint, 0);",
        },
    );

    cases.add(
        "l integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0L",
        &[_][]const u8{
            "pub const ZERO = @as(c_long, 0);",
        },
    );

    cases.add(
        "ul integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0UL",
        &[_][]const u8{
            "pub const ZERO = @as(c_ulong, 0);",
        },
    );

    cases.add(
        "lu integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0LU",
        &[_][]const u8{
            "pub const ZERO = @as(c_ulong, 0);",
        },
    );

    cases.add(
        "ll integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0LL",
        &[_][]const u8{
            "pub const ZERO = @as(c_longlong, 0);",
        },
    );

    cases.add(
        "ull integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0ULL",
        &[_][]const u8{
            "pub const ZERO = @as(c_ulonglong, 0);",
        },
    );

    cases.add(
        "llu integer suffix after 0 (zero) in macro definition",
        "#define ZERO 0LLU",
        &[_][]const u8{
            "pub const ZERO = @as(c_ulonglong, 0);",
        },
    );

    cases.add(
        "bitwise not on u-suffixed 0 (zero) in macro definition",
        "#define NOT_ZERO (~0U)",
        &[_][]const u8{
            "pub const NOT_ZERO = ~@as(c_uint, 0);",
        },
    );

    cases.add("float suffixes",
        \\#define foo 3.14f
        \\#define bar 16.e-2l
        \\#define FOO 0.12345
        \\#define BAR .12345
        \\#define baz 1e1
        \\#define BAZ 42e-3f
        \\#define foobar -73.L
        \\extern const float my_float = 1.0f;
        \\extern const double my_double = 1.0;
        \\extern const long double my_longdouble = 1.0l;
        \\extern const long double my_extended_precision_longdouble = 1.0000000000000003l;
    , &([_][]const u8{
        "pub const foo = @as(f32, 3.14);",
        "pub const bar = @as(c_longdouble, 16.e-2);",
        "pub const FOO = @as(f64, 0.12345);",
        "pub const BAR = @as(f64, 0.12345);",
        "pub const baz = @as(f64, 1e1);",
        "pub const BAZ = @as(f32, 42e-3);",
        "pub const foobar = -@as(c_longdouble, 73);",
        "pub export const my_float: f32 = 1.0;",
        "pub export const my_double: f64 = 1.0;",
        "pub export const my_longdouble: c_longdouble = 1.0;",
        switch (@bitSizeOf(c_longdouble)) {
            // TODO implement decimal format for f128 <https://github.com/ziglang/zig/issues/1181>
            // (so that f80/f128 values not exactly representable as f64 can be emitted in decimal form)
            80 => "pub export const my_extended_precision_longdouble: c_longdouble = 0x1.000000000000159ep0;",
            128 => "pub export const my_extended_precision_longdouble: c_longdouble = 0x1.000000000000159e05f1e2674d21p0;",
            else => "pub export const my_extended_precision_longdouble: c_longdouble = 1.0000000000000002;",
        },
    }));

    cases.add("macro defines hexadecimal float",
        \\#define FOO 0xf7p38
        \\#define BAR -0X8F.BP5F
        \\#define FOOBAR 0X0P+0
        \\#define BAZ -0x.0a5dp+12
        \\#define FOOBAZ 0xfE.P-1l
    , &[_][]const u8{
        "pub const FOO = @as(f64, 0xf7p38);",
        "pub const BAR = -@as(f32, 0x8F.BP5);",
        "pub const FOOBAR = @as(f64, 0x0P+0);",
        "pub const BAZ = -@as(f64, 0x0.0a5dp+12);",
        "pub const FOOBAZ = @as(c_longdouble, 0xfE.P-1);",
    });

    cases.add("comments",
        \\#define foo 1 //foo
        \\#define bar /* bar */ 2
    , &[_][]const u8{
        "pub const foo = @as(c_int, 1);",
        "pub const bar = @as(c_int, 2);",
    });

    cases.add("string prefix",
        \\#define foo L"hello"
    , &[_][]const u8{
        "pub const foo = \"hello\";",
    });

    cases.add("null statements",
        \\void foo(void) {
        \\    ;;;;;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {}
    });

    if (builtin.os.tag != .windows) {
        // Windows treats this as an enum with type c_int
        cases.add("big negative enum init values when C ABI supports long long enums",
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
            \\pub const VAL01: c_int = 0;
            \\pub const VAL02: c_int = 1;
            \\pub const VAL03: c_int = 2;
            \\pub const VAL04: c_int = 3;
            \\pub const VAL05: c_int = -1;
            \\pub const VAL06: c_int = -2;
            \\pub const VAL07: c_int = -3;
            \\pub const VAL08: c_int = -4;
            \\pub const VAL09: c_int = -3;
            \\pub const VAL10: c_int = -1000012000;
            \\pub const VAL11: c_int = -1000161000;
            \\pub const VAL12: c_int = -1000174001;
            \\pub const VAL13: c_int = -3;
            \\pub const VAL14: c_int = -1000012000;
            \\pub const VAL15: c_int = -1000161000;
            \\pub const VAL16: c_int = -3;
            \\pub const VAL17: c_int = 1000011998;
            \\pub const VAL18: c_longlong = 1152921504606846976;
            \\pub const VAL19: c_longlong = 3458764513820540927;
            \\pub const VAL20: c_longlong = 6917529027641081854;
            \\pub const VAL21: c_longlong = 6917529027641081853;
            \\pub const VAL22: c_int = 0;
            \\pub const VAL23: c_longlong = -1;
            \\pub const enum_EnumWithInits = c_longlong;
        });
    }

    cases.add("predefined expressions",
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

    cases.add("constant size array",
        \\void func(int array[20]);
    , &[_][]const u8{
        \\pub extern fn func(array: [*c]c_int) void;
    });

    cases.add("__cdecl doesn't mess up function pointers",
        \\void foo(void (__cdecl *fn_ptr)(void));
    , &[_][]const u8{
        \\pub extern fn foo(fn_ptr: ?*const fn () callconv(.C) void) void;
    });

    cases.add("void cast",
        \\void foo() {
        \\    int a;
        \\    (void) a;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    _ = &a;
        \\    _ = &a;
        \\}
    });

    cases.add("implicit cast to void *",
        \\void *foo() {
        \\    unsigned short *x;
        \\    return x;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() ?*anyopaque {
        \\    var x: [*c]c_ushort = undefined;
        \\    _ = &x;
        \\    return @as(?*anyopaque, @ptrCast(x));
        \\}
    });

    cases.add("null pointer implicit cast",
        \\int* foo(void) {
        \\    return 0;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() [*c]c_int {
        \\    return null;
        \\}
    });

    cases.add("string literal",
        \\const char *foo(void) {
        \\    return "bar";
        \\}
    , &[_][]const u8{
        \\pub export fn foo() [*c]const u8 {
        \\    return "bar";
        \\}
    });

    cases.add("return void",
        \\void foo(void) {
        \\    return;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    return;
        \\}
    });

    cases.add("for loop",
        \\void foo(void) {
        \\    for (int i = 0; i; i++) { }
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    {
        \\        var i: c_int = 0;
        \\        _ = &i;
        \\        while (i != 0) : (i += 1) {}
        \\    }
        \\}
    });

    cases.add("empty for loop",
        \\void foo(void) {
        \\    for (;;) { }
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    while (true) {}
        \\}
    });

    cases.add("for loop with simple init expression",
        \\void foo(void) {
        \\    int i;
        \\    for (i = 3; i; i--) { }
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var i: c_int = undefined;
        \\    _ = &i;
        \\    {
        \\        i = 3;
        \\        while (i != 0) : (i -= 1) {}
        \\    }
        \\}
    });

    cases.add("break statement",
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

    cases.add("continue statement",
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

    cases.add("pointer casting",
        \\float *ptrcast() {
        \\    int *a;
        \\    return (float *)a;
        \\}
    , &[_][]const u8{
        \\pub export fn ptrcast() [*c]f32 {
        \\    var a: [*c]c_int = undefined;
        \\    _ = &a;
        \\    return @as([*c]f32, @ptrCast(@alignCast(a)));
        \\}
    });

    cases.add("casting pointer to pointer",
        \\float **ptrptrcast() {
        \\    int **a;
        \\    return (float **)a;
        \\}
    , &[_][]const u8{
        \\pub export fn ptrptrcast() [*c][*c]f32 {
        \\    var a: [*c][*c]c_int = undefined;
        \\    _ = &a;
        \\    return @as([*c][*c]f32, @ptrCast(@alignCast(a)));
        \\}
    });

    cases.add("pointer conversion with different alignment",
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
        \\    var p: ?*anyopaque = undefined;
        \\    _ = &p;
        \\    {
        \\        var to_char: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(p)));
        \\        _ = &to_char;
        \\        var to_short: [*c]c_short = @as([*c]c_short, @ptrCast(@alignCast(p)));
        \\        _ = &to_short;
        \\        var to_int: [*c]c_int = @as([*c]c_int, @ptrCast(@alignCast(p)));
        \\        _ = &to_int;
        \\        var to_longlong: [*c]c_longlong = @as([*c]c_longlong, @ptrCast(@alignCast(p)));
        \\        _ = &to_longlong;
        \\    }
        \\    {
        \\        var to_char: [*c]u8 = @as([*c]u8, @ptrCast(@alignCast(p)));
        \\        _ = &to_char;
        \\        var to_short: [*c]c_short = @as([*c]c_short, @ptrCast(@alignCast(p)));
        \\        _ = &to_short;
        \\        var to_int: [*c]c_int = @as([*c]c_int, @ptrCast(@alignCast(p)));
        \\        _ = &to_int;
        \\        var to_longlong: [*c]c_longlong = @as([*c]c_longlong, @ptrCast(@alignCast(p)));
        \\        _ = &to_longlong;
        \\    }
        \\}
    });

    cases.add("while on non-bool",
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
        \\    _ = &a;
        \\    var b: f32 = undefined;
        \\    _ = &b;
        \\    var c: ?*anyopaque = undefined;
        \\    _ = &c;
        \\    while (a != 0) return 0;
        \\    while (b != 0) return 1;
        \\    while (c != null) return 2;
        \\    return 3;
        \\}
    });

    cases.add("for on non-bool",
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
        \\    _ = &a;
        \\    var b: f32 = undefined;
        \\    _ = &b;
        \\    var c: ?*anyopaque = undefined;
        \\    _ = &c;
        \\    while (a != 0) return 0;
        \\    while (b != 0) return 1;
        \\    while (c != null) return 2;
        \\    return 3;
        \\}
    });

    cases.add("bitshift",
        \\int foo(void) {
        \\    return (1 << 2) >> 1;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return (@as(c_int, 1) << @intCast(2)) >> @intCast(1);
        \\}
    });

    cases.add("sizeof",
        \\#include <stddef.h>
        \\size_t size_of(void) {
        \\        return sizeof(int);
        \\}
    , &[_][]const u8{
        \\pub export fn size_of() usize {
        \\    return @sizeOf(c_int);
        \\}
    });

    cases.add("normal deref",
        \\void foo() {
        \\    int *x;
        \\    *x = 1;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var x: [*c]c_int = undefined;
        \\    _ = &x;
        \\    x.* = 1;
        \\}
    });

    cases.add("address of operator",
        \\int foo(void) {
        \\    int x = 1234;
        \\    int *ptr = &x;
        \\    return *ptr;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    var x: c_int = 1234;
        \\    _ = &x;
        \\    var ptr: [*c]c_int = &x;
        \\    _ = &ptr;
        \\    return ptr.*;
        \\}
    });

    cases.add("bin not",
        \\int foo() {
        \\    int x;
        \\    return ~x;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    var x: c_int = undefined;
        \\    _ = &x;
        \\    return ~x;
        \\}
    });

    cases.add("bool not",
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
        \\    _ = &a;
        \\    var b: f32 = undefined;
        \\    _ = &b;
        \\    var c: ?*anyopaque = undefined;
        \\    _ = &c;
        \\    return @intFromBool(!(a == @as(c_int, 0)));
        \\    return @intFromBool(!(a != 0));
        \\    return @intFromBool(!(b != 0));
        \\    return @intFromBool(!(c != null));
        \\}
    });

    cases.add("__extension__ cast",
        \\int foo(void) {
        \\    return __extension__ 1;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return 1;
        \\}
    });

    if (builtin.os.tag != .windows) {
        // sysv_abi not currently supported on windows
        cases.add("Macro qualified functions",
            \\void __attribute__((sysv_abi)) foo(void);
        , &[_][]const u8{
            \\pub extern fn foo() void;
        });
    }

    cases.add("Forward-declared enum",
        \\extern enum enum_ty my_enum;
        \\enum enum_ty { FOO };
    , &[_][]const u8{
        \\pub const FOO: c_int = 0;
        \\pub const enum_enum_ty = c_int;
        \\pub extern var my_enum: enum_enum_ty;
    });

    cases.add("Parameterless function pointers",
        \\typedef void (*fn0)();
        \\typedef void (*fn1)(char);
    , &[_][]const u8{
        \\pub const fn0 = ?*const fn (...) callconv(.C) void;
        \\pub const fn1 = ?*const fn (u8) callconv(.C) void;
    });

    cases.addWithTarget("Calling convention", .{
        .cpu_arch = .x86,
        .os_tag = .linux,
        .abi = .none,
    },
        \\void __attribute__((fastcall)) foo1(float *a);
        \\void __attribute__((stdcall)) foo2(float *a);
        \\void __attribute__((vectorcall)) foo3(float *a);
        \\void __attribute__((cdecl)) foo4(float *a);
        \\void __attribute__((thiscall)) foo5(float *a);
    , &[_][]const u8{
        \\pub extern fn foo1(a: [*c]f32) callconv(.Fastcall) void;
        \\pub extern fn foo2(a: [*c]f32) callconv(.Stdcall) void;
        \\pub extern fn foo3(a: [*c]f32) callconv(.Vectorcall) void;
        \\pub extern fn foo4(a: [*c]f32) void;
        \\pub extern fn foo5(a: [*c]f32) callconv(.Thiscall) void;
    });

    cases.addWithTarget("Calling convention", std.Target.Query.parse(.{
        .arch_os_abi = "arm-linux-none",
        .cpu_features = "generic+v8_5a",
    }) catch unreachable,
        \\void __attribute__((pcs("aapcs"))) foo1(float *a);
        \\void __attribute__((pcs("aapcs-vfp"))) foo2(float *a);
    , &[_][]const u8{
        \\pub extern fn foo1(a: [*c]f32) callconv(.AAPCS) void;
        \\pub extern fn foo2(a: [*c]f32) callconv(.AAPCSVFP) void;
    });

    cases.addWithTarget("Calling convention", std.Target.Query.parse(.{
        .arch_os_abi = "aarch64-linux-none",
        .cpu_features = "generic+v8_5a",
    }) catch unreachable,
        \\void __attribute__((aarch64_vector_pcs)) foo1(float *a);
    , &[_][]const u8{
        \\pub extern fn foo1(a: [*c]f32) callconv(.Vectorcall) void;
    });

    cases.add("Parameterless function prototypes",
        \\void a() {}
        \\void b(void) {}
        \\void c();
        \\void d(void);
        \\static void e() {}
        \\static void f(void) {}
        \\static void g();
        \\static void h(void);
    , &[_][]const u8{
        \\pub export fn a() void {}
        \\pub export fn b() void {}
        \\pub extern fn c(...) void;
        \\pub extern fn d() void;
        \\pub fn e() callconv(.C) void {}
        \\pub fn f() callconv(.C) void {}
        \\pub extern fn g() void;
        \\pub extern fn h() void;
    });

    cases.add("variable declarations",
        \\extern char arr0[] = "hello";
        \\static char arr1[] = "hello";
        \\char arr2[] = "hello";
    , &[_][]const u8{
        \\pub export var arr0: [5:0]u8 = "hello".*;
        \\pub var arr1: [5:0]u8 = "hello".*;
        \\pub export var arr2: [5:0]u8 = "hello".*;
    });

    cases.add("array initializer expr",
        \\static void foo(void){
        \\    char arr[10] ={1};
        \\    char *arr1[10] ={0};
        \\}
    , &[_][]const u8{
        \\pub fn foo() callconv(.C) void {
        \\    var arr: [10]u8 = [1]u8{
        \\        1,
        \\    } ++ [1]u8{0} ** 9;
        \\    _ = &arr;
        \\    var arr1: [10][*c]u8 = [1][*c]u8{
        \\        null,
        \\    } ++ [1][*c]u8{null} ** 9;
        \\    _ = &arr1;
        \\}
    });

    cases.add("enums",
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
        \\pub const a: c_int = 0;
        \\pub const b: c_int = 1;
        \\pub const c: c_int = 2;
        \\pub const d =
        ++ " " ++ default_enum_type ++
            \\;
            \\pub const e: c_int = 0;
            \\pub const f: c_int = 4;
            \\pub const g: c_int = 5;
            \\const enum_unnamed_1 =
        ++ " " ++ default_enum_type ++
            \\;
            \\pub export var h: enum_unnamed_1 = @as(c_uint, @bitCast(e));
            \\pub const i: c_int = 0;
            \\pub const j: c_int = 1;
            \\pub const k: c_int = 2;
            \\const enum_unnamed_2 =
        ++ " " ++ default_enum_type ++
            \\;
            \\pub const struct_Baz = extern struct {
            \\    l: enum_unnamed_2 = @import("std").mem.zeroes(enum_unnamed_2),
            \\    m: d = @import("std").mem.zeroes(d),
            \\};
            \\pub const n: c_int = 0;
            \\pub const o: c_int = 1;
            \\pub const p: c_int = 2;
            \\pub const enum_i =
        ++ " " ++ default_enum_type ++
            \\;
        ,
        "pub const Baz = struct_Baz;",
    });

    cases.add("#define a char literal",
        \\#define A_CHAR  'a'
    , &[_][]const u8{
        \\pub const A_CHAR = 'a';
    });

    cases.add("comment after integer literal",
        \\#define SDL_INIT_VIDEO 0x00000020  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_int, 0x00000020);
    });

    cases.add("u integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020u  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_uint, 0x00000020);
    });

    cases.add("l integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020l  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_long, 0x00000020);
    });

    cases.add("ul integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ul  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulong, 0x00000020);
    });

    cases.add("lu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020lu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulong, 0x00000020);
    });

    cases.add("ll integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ll  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_longlong, 0x00000020);
    });

    cases.add("ull integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020ull  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulonglong, 0x00000020);
    });

    cases.add("llu integer suffix after hex literal",
        \\#define SDL_INIT_VIDEO 0x00000020llu  /**< SDL_INIT_VIDEO implies SDL_INIT_EVENTS */
    , &[_][]const u8{
        \\pub const SDL_INIT_VIDEO = @as(c_ulonglong, 0x00000020);
    });

    cases.add("generate inline func for #define global extern fn",
        \\extern void (*fn_ptr)(void);
        \\#define foo fn_ptr
        \\
        \\extern char (*fn_ptr2)(int, float);
        \\#define bar fn_ptr2
    , &[_][]const u8{
        \\pub extern var fn_ptr: ?*const fn () callconv(.C) void;
        ,
        \\pub inline fn foo() void {
        \\    return fn_ptr.?();
        \\}
        ,
        \\pub extern var fn_ptr2: ?*const fn (c_int, f32) callconv(.C) u8;
        ,
        \\pub inline fn bar(arg_1: c_int, arg_2: f32) u8 {
        \\    return fn_ptr2.?(arg_1, arg_2);
        \\}
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
        \\pub const PFNGLCLEARPROC = ?*const fn (GLbitfield) callconv(.C) void;
        \\pub const OpenGLProc = ?*const fn () callconv(.C) void;
        \\const struct_unnamed_1 = extern struct {
        \\    Clear: PFNGLCLEARPROC = @import("std").mem.zeroes(PFNGLCLEARPROC),
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

    cases.add("macro pointer cast",
        \\#define NRF_GPIO_BASE 0
        \\typedef struct { int dummy; } NRF_GPIO_Type;
        \\#define NRF_GPIO ((NRF_GPIO_Type *) NRF_GPIO_BASE)
    , &[_][]const u8{
        \\pub const NRF_GPIO = @import("std").zig.c_translation.cast([*c]NRF_GPIO_Type, NRF_GPIO_BASE);
    });

    cases.add("basic macro function",
        \\extern int c;
        \\#define BASIC(c) (c*2)
        \\#define FOO(L,b) (L + b)
        \\#define BAR() (c*c)
    , &[_][]const u8{
        \\pub extern var c: c_int;
        ,
        \\pub inline fn BASIC(c_1: anytype) @TypeOf(c_1 * @as(c_int, 2)) {
        \\    _ = &c_1;
        \\    return c_1 * @as(c_int, 2);
        \\}
        ,
        \\pub inline fn FOO(L: anytype, b: anytype) @TypeOf(L + b) {
        \\    _ = &L;
        \\    _ = &b;
        \\    return L + b;
        \\}
        ,
        \\pub inline fn BAR() @TypeOf(c * c) {
        \\    return c * c;
        \\}
    });

    cases.add("macro defines string literal with hex",
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

    cases.add("macro add",
        \\#define D3_AHB1PERIPH_BASE 0
        \\#define PERIPH_BASE               (0x40000000UL) /*!< Base address of : AHB/APB Peripherals                                                   */
        \\#define D3_APB1PERIPH_BASE       (PERIPH_BASE + 0x18000000UL)
        \\#define RCC_BASE              (D3_AHB1PERIPH_BASE + 0x4400UL)
    , &[_][]const u8{
        \\pub const PERIPH_BASE = @as(c_ulong, 0x40000000);
        ,
        \\pub const D3_APB1PERIPH_BASE = PERIPH_BASE + @as(c_ulong, 0x18000000);
        ,
        \\pub const RCC_BASE = D3_AHB1PERIPH_BASE + @as(c_ulong, 0x4400);
    });

    cases.add("variable aliasing",
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
        \\pub var a: c_long = 2;
        \\pub var b: c_long = 2;
        \\pub var c: c_int = 4;
        \\pub export fn foo(arg_c_1: u8) void {
        \\    var c_1 = arg_c_1;
        \\    _ = &c_1;
        \\    var a_2: c_int = undefined;
        \\    _ = &a_2;
        \\    var b_3: u8 = 123;
        \\    _ = &b_3;
        \\    b_3 = @as(u8, @bitCast(@as(i8, @truncate(a_2))));
        \\    {
        \\        var d: c_int = 5;
        \\        _ = &d;
        \\    }
        \\    var d: c_uint = @as(c_uint, @bitCast(@as(c_int, 440)));
        \\    _ = &d;
        \\}
    });

    cases.add("comma operator",
        \\int foo() {
        \\    2, 4;
        \\    return 2, 4, 6;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    _ = blk: {
        \\        _ = @as(c_int, 2);
        \\        break :blk @as(c_int, 4);
        \\    };
        \\    return blk: {
        \\        _ = blk_1: {
        \\            _ = @as(c_int, 2);
        \\            break :blk_1 @as(c_int, 4);
        \\        };
        \\        break :blk @as(c_int, 6);
        \\    };
        \\}
    });

    cases.add("worst-case assign",
        \\void foo() {
        \\    int a;
        \\    int b;
        \\    a = b = 2;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    _ = &a;
        \\    var b: c_int = undefined;
        \\    _ = &b;
        \\    a = blk: {
        \\        const tmp = @as(c_int, 2);
        \\        b = tmp;
        \\        break :blk tmp;
        \\    };
        \\}
    });

    cases.add("while loops",
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
        \\    _ = &a;
        \\    while (true) {
        \\        a = 2;
        \\    }
        \\    while (true) {
        \\        var a_1: c_int = 4;
        \\        _ = &a_1;
        \\        a_1 = 9;
        \\        return blk: {
        \\            _ = @as(c_int, 6);
        \\            break :blk a_1;
        \\        };
        \\    }
        \\    while (true) {
        \\        var a_1: c_int = 2;
        \\        _ = &a_1;
        \\        a_1 = 12;
        \\    }
        \\    while (true) {
        \\        a = 7;
        \\    }
        \\    return 0;
        \\}
    });

    cases.add("for loops",
        \\void foo() {
        \\    for (int i = 2, b = 4; i + 2; i = 2) {
        \\        int a = 2;
        \\        a = 6, 5, 7;
        \\    }
        \\    char i = 2;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    {
        \\        var i: c_int = 2;
        \\        _ = &i;
        \\        var b: c_int = 4;
        \\        _ = &b;
        \\        while ((i + @as(c_int, 2)) != 0) : (i = 2) {
        \\            var a: c_int = 2;
        \\            _ = &a;
        \\            _ = blk: {
        \\                _ = blk_1: {
        \\                    a = 6;
        \\                    break :blk_1 @as(c_int, 5);
        \\                };
        \\                break :blk @as(c_int, 7);
        \\            };
        \\        }
        \\    }
        \\    var i: u8 = 2;
        \\    _ = &i;
        \\}
    });

    cases.add("shadowing primitive types",
        \\unsigned anyerror = 2;
        \\#define noreturn _Noreturn
        \\typedef enum {
        \\    f32,
        \\    u32,
        \\} BadEnum;
    , &[_][]const u8{
        \\pub export var @"anyerror": c_uint = 2;
        ,
        \\pub const @"noreturn" = @compileError("unable to translate C expr: unexpected token '_Noreturn'");
        ,
        \\pub const @"f32": c_int = 0;
        \\pub const @"u32": c_int = 1;
        \\pub const BadEnum = c_uint;
    });

    cases.add("floats",
        \\float a = 3.1415;
        \\double b = 3.1415;
        \\int c = 3.1415;
        \\double d = 3;
    , &[_][]const u8{
        \\pub export var a: f32 = @as(f32, @floatCast(3.1415));
        \\pub export var b: f64 = 3.1415;
        \\pub export var c: c_int = @as(c_int, @intFromFloat(3.1415));
        \\pub export var d: f64 = 3;
    });

    cases.add("conditional operator",
        \\int bar(void) {
        \\    if (2 ? 5 : 5 ? 4 : 6) 2;
        \\    return  2 ? 5 : 5 ? 4 : 6;
        \\}
    , &[_][]const u8{
        \\pub export fn bar() c_int {
        \\    if ((if (true) @as(c_int, 5) else if (true) @as(c_int, 4) else @as(c_int, 6)) != 0) {
        \\        _ = @as(c_int, 2);
        \\    }
        \\    return if (true) @as(c_int, 5) else if (true) @as(c_int, 4) else @as(c_int, 6);
        \\}
    });

    cases.add("switch on int",
        \\void switch_fn(int i) {
        \\    int res = 0;
        \\    switch (i) {
        \\        case 0:
        \\            res = 1;
        \\        case 1 ... 3:
        \\            res = 2;
        \\        default:
        \\            res = 3 * i;
        \\            break;
        \\            break;
        \\        case 7: {
        \\           res = 7;
        \\           break;
        \\        }
        \\        case 4:
        \\		case 5:
        \\            res = 69;
        \\        {
        \\            res = 5;
        \\			  return;
        \\        }
        \\        case 6:
        \\            switch (res) {
        \\                case 9: break;
        \\            }
        \\            res = 1;
        \\			  return;
        \\    }
        \\}
    , &[_][]const u8{
        \\pub export fn switch_fn(arg_i: c_int) void {
        \\    var i = arg_i;
        \\    _ = &i;
        \\    var res: c_int = 0;
        \\    _ = &res;
        \\    while (true) {
        \\        switch (i) {
        \\            @as(c_int, 0) => {
        \\                res = 1;
        \\                res = 2;
        \\                res = @as(c_int, 3) * i;
        \\                break;
        \\            },
        \\            @as(c_int, 1)...@as(c_int, 3) => {
        \\                res = 2;
        \\                res = @as(c_int, 3) * i;
        \\                break;
        \\            },
        \\            else => {
        \\                res = @as(c_int, 3) * i;
        \\                break;
        \\            },
        \\            @as(c_int, 7) => {
        \\                {
        \\                    res = 7;
        \\                    break;
        \\                }
        \\            },
        \\            @as(c_int, 4), @as(c_int, 5) => {
        \\                res = 69;
        \\                {
        \\                    res = 5;
        \\                    return;
        \\                }
        \\            },
        \\            @as(c_int, 6) => {
        \\                while (true) {
        \\                    switch (res) {
        \\                        @as(c_int, 9) => break,
        \\                        else => {},
        \\                    }
        \\                    break;
        \\                }
        \\                res = 1;
        \\                return;
        \\            },
        \\        }
        \\        break;
        \\    }
        \\}
    });
    cases.add("undefined array global",
        \\int array[100] = {};
    , &[_][]const u8{
        \\pub export var array: [100]c_int = [1]c_int{0} ** 100;
    });

    cases.add("restrict -> noalias",
        \\void foo(void *restrict bar, void *restrict);
    , &[_][]const u8{
        \\pub extern fn foo(noalias bar: ?*anyopaque, noalias ?*anyopaque) void;
    });

    cases.add("assign",
        \\void max(int a) {
        \\    int tmp;
        \\    tmp = a;
        \\    a = tmp;
        \\}
    , &[_][]const u8{
        \\pub export fn max(arg_a: c_int) void {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var tmp: c_int = undefined;
        \\    _ = &tmp;
        \\    tmp = a;
        \\    a = tmp;
        \\}
    });

    cases.add("chaining assign",
        \\void max(int a) {
        \\    int b, c;
        \\    c = b = a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(arg_a: c_int) void {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var b: c_int = undefined;
        \\    _ = &b;
        \\    var c: c_int = undefined;
        \\    _ = &c;
        \\    c = blk: {
        \\        const tmp = a;
        \\        b = tmp;
        \\        break :blk tmp;
        \\    };
        \\}
    });

    cases.add("anonymous enum",
        \\enum {
        \\    One,
        \\    Two,
        \\};
    , &[_][]const u8{
        \\pub const One: c_int = 0;
        \\pub const Two: c_int = 1;
        \\const enum_unnamed_1 =
        ++ " " ++ default_enum_type ++
            \\;
    });

    cases.add("c style cast",
        \\int int_from_float(float a) {
        \\    return (int)a;
        \\}
    , &[_][]const u8{
        \\pub export fn int_from_float(arg_a: f32) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    return @as(c_int, @intFromFloat(a));
        \\}
    });

    cases.add("escape sequences",
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
        \\    var a: u8 = '\'';
        \\    _ = &a;
        \\    var b: u8 = '\\';
        \\    _ = &b;
        \\    var c: u8 = '\x07';
        \\    _ = &c;
        \\    var d: u8 = '\x08';
        \\    _ = &d;
        \\    var e: u8 = '\x0c';
        \\    _ = &e;
        \\    var f: u8 = '\n';
        \\    _ = &f;
        \\    var g: u8 = '\r';
        \\    _ = &g;
        \\    var h: u8 = '\t';
        \\    _ = &h;
        \\    var i: u8 = '\x0b';
        \\    _ = &i;
        \\    var j: u8 = '\x00';
        \\    _ = &j;
        \\    var k: u8 = '"';
        \\    _ = &k;
        \\    return "'\\\x07\x08\x0c\n\r\t\x0b\x00\"";
        \\}
    });

    cases.add("do loop",
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
        \\    _ = &a;
        \\    while (true) {
        \\        a = a - @as(c_int, 1);
        \\        if (!(a != 0)) break;
        \\    }
        \\    var b: c_int = 2;
        \\    _ = &b;
        \\    while (true) {
        \\        b = b - @as(c_int, 1);
        \\        if (!(b != 0)) break;
        \\    }
        \\}
    });

    cases.add("logical and, logical or, on non-bool values, extra parens",
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
        \\    int k = (a || (int)d);
        \\    int l = ((int)d && b);
        \\    int m = (c || (unsigned int)d);
        \\    SomeTypedef td = 44;
        \\    int o = (td || b);
        \\    int p = (c && td);
        \\    return ((((((((((e + f) + g) + h) + i) + j) + k) + l) + m) + o) + p);
        \\}
    , &[_][]const u8{
        \\pub const FooA: c_int = 0;
        \\pub const FooB: c_int = 1;
        \\pub const FooC: c_int = 2;
        \\pub const enum_Foo =
        ++ " " ++ default_enum_type ++
            \\;
            \\pub const SomeTypedef = c_int;
            \\pub export fn and_or_non_bool(arg_a: c_int, arg_b: f32, arg_c: ?*anyopaque) c_int {
            \\    var a = arg_a;
            \\    _ = &a;
            \\    var b = arg_b;
            \\    _ = &b;
            \\    var c = arg_c;
            \\    _ = &c;
            \\    var d: enum_Foo = @as(c_uint, @bitCast(FooA));
            \\    _ = &d;
            \\    var e: c_int = @intFromBool((a != 0) and (b != 0));
            \\    _ = &e;
            \\    var f: c_int = @intFromBool((b != 0) and (c != null));
            \\    _ = &f;
            \\    var g: c_int = @intFromBool((a != 0) and (c != null));
            \\    _ = &g;
            \\    var h: c_int = @intFromBool((a != 0) or (b != 0));
            \\    _ = &h;
            \\    var i: c_int = @intFromBool((b != 0) or (c != null));
            \\    _ = &i;
            \\    var j: c_int = @intFromBool((a != 0) or (c != null));
            \\    _ = &j;
            \\    var k: c_int = @intFromBool((a != 0) or (@as(c_int, @bitCast(d)) != 0));
            \\    _ = &k;
            \\    var l: c_int = @intFromBool((@as(c_int, @bitCast(d)) != 0) and (b != 0));
            \\    _ = &l;
            \\    var m: c_int = @intFromBool((c != null) or (d != 0));
            \\    _ = &m;
            \\    var td: SomeTypedef = 44;
            \\    _ = &td;
            \\    var o: c_int = @intFromBool((td != 0) or (b != 0));
            \\    _ = &o;
            \\    var p: c_int = @intFromBool((c != null) and (td != 0));
            \\    _ = &p;
            \\    return (((((((((e + f) + g) + h) + i) + j) + k) + l) + m) + o) + p;
            \\}
        ,
        \\pub const Foo = enum_Foo;
    });

    cases.add("bitwise binary operators, simpler parens",
        \\int max(int a, int b) {
        \\    return (a & b) ^ (a | b);
        \\}
    , &[_][]const u8{
        \\pub export fn max(arg_a: c_int, arg_b: c_int) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var b = arg_b;
        \\    _ = &b;
        \\    return (a & b) ^ (a | b);
        \\}
    });

    cases.add("comparison operators (no if)", // TODO Come up with less contrived tests? Make sure to cover all these comparisons.
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
        \\pub export fn test_comparisons(arg_a: c_int, arg_b: c_int) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var b = arg_b;
        \\    _ = &b;
        \\    var c: c_int = @intFromBool(a < b);
        \\    _ = &c;
        \\    var d: c_int = @intFromBool(a > b);
        \\    _ = &d;
        \\    var e: c_int = @intFromBool(a <= b);
        \\    _ = &e;
        \\    var f: c_int = @intFromBool(a >= b);
        \\    _ = &f;
        \\    var g: c_int = @intFromBool(c < d);
        \\    _ = &g;
        \\    var h: c_int = @intFromBool(e < f);
        \\    _ = &h;
        \\    var i: c_int = @intFromBool(g < h);
        \\    _ = &i;
        \\    return i;
        \\}
    });

    cases.add("==, !=",
        \\int max(int a, int b) {
        \\    if (a == b)
        \\        return a;
        \\    if (a != b)
        \\        return b;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(arg_a: c_int, arg_b: c_int) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var b = arg_b;
        \\    _ = &b;
        \\    if (a == b) return a;
        \\    if (a != b) return b;
        \\    return a;
        \\}
    });

    cases.add("typedeffed bool expression",
        \\typedef char* yes;
        \\void foo(void) {
        \\    yes a;
        \\    if (a) 2;
        \\}
    , &[_][]const u8{
        \\pub const yes = [*c]u8;
        \\pub export fn foo() void {
        \\    var a: yes = undefined;
        \\    _ = &a;
        \\    if (a != null) {
        \\        _ = @as(c_int, 2);
        \\    }
        \\}
    });

    cases.add("statement expression",
        \\int foo(void) {
        \\    return ({
        \\        int a = 1;
        \\        a;
        \\        a;
        \\    });
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_int {
        \\    return blk: {
        \\        var a: c_int = 1;
        \\        _ = &a;
        \\        _ = &a;
        \\        break :blk a;
        \\    };
        \\}
    });

    cases.add("field access expression",
        \\#define ARROW a->b
        \\#define DOT a.b
        \\extern struct Foo {
        \\    int b;
        \\}a;
        \\float b = 2.0f;
        \\void foo(void) {
        \\    struct Foo *c;
        \\    a.b;
        \\    c->b;
        \\}
    , &[_][]const u8{
        \\pub const struct_Foo = extern struct {
        \\    b: c_int = @import("std").mem.zeroes(c_int),
        \\};
        \\pub extern var a: struct_Foo;
        \\pub export var b: f32 = 2.0;
        \\pub export fn foo() void {
        \\    var c: [*c]struct_Foo = undefined;
        \\    _ = &c;
        \\    _ = a.b;
        \\    _ = c.*.b;
        \\}
        ,
        \\pub const DOT = a.b;
        ,
        \\pub const ARROW = a.*.b;
    });

    cases.add("array access",
        \\#define ACCESS array[2]
        \\int array[100] = {};
        \\int foo(int index) {
        \\    return array[index];
        \\}
    , &[_][]const u8{
        \\pub export var array: [100]c_int = [1]c_int{0} ** 100;
        \\pub export fn foo(arg_index: c_int) c_int {
        \\    var index = arg_index;
        \\    _ = &index;
        \\    return array[@as(c_uint, @intCast(index))];
        \\}
        ,
        \\pub const ACCESS = array[@as(usize, @intCast(@as(c_int, 2)))];
    });

    cases.add("cast signed array index to unsigned",
        \\void foo() {
        \\  int a[10], i = 0;
        \\  a[i] = 0;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: [10]c_int = undefined;
        \\    _ = &a;
        \\    var i: c_int = 0;
        \\    _ = &i;
        \\    a[@as(c_uint, @intCast(i))] = 0;
        \\}
    });

    cases.add("long long array index cast to usize",
        \\void foo() {
        \\  long long a[10], i = 0;
        \\  a[i] = 0;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: [10]c_longlong = undefined;
        \\    _ = &a;
        \\    var i: c_longlong = 0;
        \\    _ = &i;
        \\    a[@as(usize, @intCast(i))] = 0;
        \\}
    });

    cases.add("unsigned array index skips cast",
        \\void foo() {
        \\  unsigned int a[10], i = 0;
        \\  a[i] = 0;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: [10]c_uint = undefined;
        \\    _ = &a;
        \\    var i: c_uint = 0;
        \\    _ = &i;
        \\    a[i] = 0;
        \\}
    });

    cases.add("macro call",
        \\#define CALL(arg) bar(arg)
        \\int bar(int x) { return x; }
    , &[_][]const u8{
        \\pub inline fn CALL(arg: anytype) @TypeOf(bar(arg)) {
        \\    _ = &arg;
        \\    return bar(arg);
        \\}
    });

    cases.add("macro call with no args",
        \\#define CALL(arg) bar()
        \\int bar(void) { return 0; }
    , &[_][]const u8{
        \\pub inline fn CALL(arg: anytype) @TypeOf(bar()) {
        \\    _ = &arg;
        \\    return bar();
        \\}
    });

    cases.add("logical and, logical or",
        \\int max(int a, int b) {
        \\    if (a < b || a == b)
        \\        return b;
        \\    if (a >= b && a == b)
        \\        return a;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn max(arg_a: c_int, arg_b: c_int) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var b = arg_b;
        \\    _ = &b;
        \\    if ((a < b) or (a == b)) return b;
        \\    if ((a >= b) and (a == b)) return a;
        \\    return a;
        \\}
    });

    cases.add("simple if statement",
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
        \\pub export fn max(arg_a: c_int, arg_b: c_int) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var b = arg_b;
        \\    _ = &b;
        \\    if (a < b) return b;
        \\    if (a < b) return b else return a;
        \\    if (a < b) {} else {}
        \\    return 0;
        \\}
    });

    cases.add("if statements",
        \\void foo() {
        \\    if (2) {
        \\        int a = 2;
        \\    }
        \\    if (2, 5) {
        \\        int a = 2;
        \\    }
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    if (true) {
        \\        var a: c_int = 2;
        \\        _ = &a;
        \\    }
        \\    if ((blk: {
        \\        _ = @as(c_int, 2);
        \\        break :blk @as(c_int, 5);
        \\    }) != 0) {
        \\        var a: c_int = 2;
        \\        _ = &a;
        \\    }
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
        \\pub const A: c_int = 0;
        \\pub const B: c_int = 1;
        \\pub const C: c_int = 2;
        \\pub const enum_SomeEnum =
        ++ " " ++ default_enum_type ++
            \\;
            \\pub export fn if_none_bool(arg_a: c_int, arg_b: f32, arg_c: ?*anyopaque, arg_d: enum_SomeEnum) c_int {
            \\    var a = arg_a;
            \\    _ = &a;
            \\    var b = arg_b;
            \\    _ = &b;
            \\    var c = arg_c;
            \\    _ = &c;
            \\    var d = arg_d;
            \\    _ = &d;
            \\    if (a != 0) return 0;
            \\    if (b != 0) return 1;
            \\    if (c != null) return 2;
            \\    if (d != 0) return 3;
            \\    return 4;
            \\}
    });

    cases.add("simple data types",
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

    cases.add("simple function",
        \\int abs(int a) {
        \\    return a < 0 ? -a : a;
        \\}
    , &[_][]const u8{
        \\pub export fn abs(arg_a: c_int) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    return if (a < @as(c_int, 0)) -a else a;
        \\}
    });

    cases.add("post increment",
        \\unsigned foo1(unsigned a) {
        \\    a++;
        \\    return a;
        \\}
        \\int foo2(int a) {
        \\    a++;
        \\    return a;
        \\}
        \\int *foo3(int *a) {
        \\    a++;
        \\    return a;
        \\}
    , &[_][]const u8{
        \\pub export fn foo1(arg_a: c_uint) c_uint {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    a +%= 1;
        \\    return a;
        \\}
        \\pub export fn foo2(arg_a: c_int) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    a += 1;
        \\    return a;
        \\}
        \\pub export fn foo3(arg_a: [*c]c_int) [*c]c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    a += 1;
        \\    return a;
        \\}
    });

    cases.add("deref function pointer",
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
        \\    var f: ?*const fn () callconv(.C) void = &foo;
        \\    _ = &f;
        \\    var b: ?*const fn () callconv(.C) c_int = &baz;
        \\    _ = &b;
        \\    f.?();
        \\    f.?();
        \\    foo();
        \\    _ = b.?();
        \\    _ = b.?();
        \\    _ = baz();
        \\}
    });

    cases.add("pre increment/decrement",
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
        \\    _ = &i;
        \\    var u: c_uint = 0;
        \\    _ = &u;
        \\    i += 1;
        \\    i -= 1;
        \\    u +%= 1;
        \\    u -%= 1;
        \\    i = blk: {
        \\        const ref = &i;
        \\        ref.* += 1;
        \\        break :blk ref.*;
        \\    };
        \\    i = blk: {
        \\        const ref = &i;
        \\        ref.* -= 1;
        \\        break :blk ref.*;
        \\    };
        \\    u = blk: {
        \\        const ref = &u;
        \\        ref.* +%= 1;
        \\        break :blk ref.*;
        \\    };
        \\    u = blk: {
        \\        const ref = &u;
        \\        ref.* -%= 1;
        \\        break :blk ref.*;
        \\    };
        \\}
    });

    cases.add("shift right assign",
        \\int log2(unsigned a) {
        \\    int i = 0;
        \\    while (a > 0) {
        \\        a >>= 1;
        \\    }
        \\    return i;
        \\}
    , &[_][]const u8{
        \\pub export fn log2(arg_a: c_uint) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var i: c_int = 0;
        \\    _ = &i;
        \\    while (a > @as(c_uint, @bitCast(@as(c_int, 0)))) {
        \\        a >>= @intCast(@as(c_int, 1));
        \\    }
        \\    return i;
        \\}
    });

    cases.add("shift right assign with a fixed size type",
        \\#include <stdint.h>
        \\int log2(uint32_t a) {
        \\    int i = 0;
        \\    while (a > 0) {
        \\        a >>= 1;
        \\    }
        \\    return i;
        \\}
    , &[_][]const u8{
        \\pub export fn log2(arg_a: u32) c_int {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    var i: c_int = 0;
        \\    _ = &i;
        \\    while (a > @as(u32, @bitCast(@as(c_int, 0)))) {
        \\        a >>= @intCast(@as(c_int, 1));
        \\    }
        \\    return i;
        \\}
    });

    cases.add("compound assignment operators",
        \\void foo(void) {
        \\    int a = 0;
        \\    unsigned b = 0;
        \\    a += (a += 1);
        \\    a -= (a -= 1);
        \\    a *= (a *= 1);
        \\    a &= (a &= 1);
        \\    a |= (a |= 1);
        \\    a ^= (a ^= 1);
        \\    a >>= (a >>= 1);
        \\    a <<= (a <<= 1);
        \\    a /= (a /= 1);
        \\    a %= (a %= 1);
        \\    b /= (b /= 1);
        \\    b %= (b %= 1);
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = 0;
        \\    _ = &a;
        \\    var b: c_uint = 0;
        \\    _ = &b;
        \\    a += blk: {
        \\        const ref = &a;
        \\        ref.* += @as(c_int, 1);
        \\        break :blk ref.*;
        \\    };
        \\    a -= blk: {
        \\        const ref = &a;
        \\        ref.* -= @as(c_int, 1);
        \\        break :blk ref.*;
        \\    };
        \\    a *= blk: {
        \\        const ref = &a;
        \\        ref.* *= @as(c_int, 1);
        \\        break :blk ref.*;
        \\    };
        \\    a &= blk: {
        \\        const ref = &a;
        \\        ref.* &= @as(c_int, 1);
        \\        break :blk ref.*;
        \\    };
        \\    a |= blk: {
        \\        const ref = &a;
        \\        ref.* |= @as(c_int, 1);
        \\        break :blk ref.*;
        \\    };
        \\    a ^= blk: {
        \\        const ref = &a;
        \\        ref.* ^= @as(c_int, 1);
        \\        break :blk ref.*;
        \\    };
        \\    a >>= @intCast(blk: {
        \\        const ref = &a;
        \\        ref.* >>= @intCast(@as(c_int, 1));
        \\        break :blk ref.*;
        \\    });
        \\    a <<= @intCast(blk: {
        \\        const ref = &a;
        \\        ref.* <<= @intCast(@as(c_int, 1));
        \\        break :blk ref.*;
        \\    });
        \\    a = @divTrunc(a, blk: {
        \\        const ref = &a;
        \\        ref.* = @divTrunc(ref.*, @as(c_int, 1));
        \\        break :blk ref.*;
        \\    });
        \\    a = @import("std").zig.c_translation.signedRemainder(a, blk: {
        \\        const ref = &a;
        \\        ref.* = @import("std").zig.c_translation.signedRemainder(ref.*, @as(c_int, 1));
        \\        break :blk ref.*;
        \\    });
        \\    b /= blk: {
        \\        const ref = &b;
        \\        ref.* /= @as(c_uint, @bitCast(@as(c_int, 1)));
        \\        break :blk ref.*;
        \\    };
        \\    b %= blk: {
        \\        const ref = &b;
        \\        ref.* %= @as(c_uint, @bitCast(@as(c_int, 1)));
        \\        break :blk ref.*;
        \\    };
        \\}
    });

    cases.add("compound assignment operators unsigned",
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
        \\    var a: c_uint = 0;
        \\    _ = &a;
        \\    a +%= blk: {
        \\        const ref = &a;
        \\        ref.* +%= @as(c_uint, @bitCast(@as(c_int, 1)));
        \\        break :blk ref.*;
        \\    };
        \\    a -%= blk: {
        \\        const ref = &a;
        \\        ref.* -%= @as(c_uint, @bitCast(@as(c_int, 1)));
        \\        break :blk ref.*;
        \\    };
        \\    a *%= blk: {
        \\        const ref = &a;
        \\        ref.* *%= @as(c_uint, @bitCast(@as(c_int, 1)));
        \\        break :blk ref.*;
        \\    };
        \\    a &= blk: {
        \\        const ref = &a;
        \\        ref.* &= @as(c_uint, @bitCast(@as(c_int, 1)));
        \\        break :blk ref.*;
        \\    };
        \\    a |= blk: {
        \\        const ref = &a;
        \\        ref.* |= @as(c_uint, @bitCast(@as(c_int, 1)));
        \\        break :blk ref.*;
        \\    };
        \\    a ^= blk: {
        \\        const ref = &a;
        \\        ref.* ^= @as(c_uint, @bitCast(@as(c_int, 1)));
        \\        break :blk ref.*;
        \\    };
        \\    a >>= @intCast(blk: {
        \\        const ref = &a;
        \\        ref.* >>= @intCast(@as(c_int, 1));
        \\        break :blk ref.*;
        \\    });
        \\    a <<= @intCast(blk: {
        \\        const ref = &a;
        \\        ref.* <<= @intCast(@as(c_int, 1));
        \\        break :blk ref.*;
        \\    });
        \\}
    });

    cases.add("post increment/decrement",
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
        \\    _ = &i;
        \\    var u: c_uint = 0;
        \\    _ = &u;
        \\    i += 1;
        \\    i -= 1;
        \\    u +%= 1;
        \\    u -%= 1;
        \\    i = blk: {
        \\        const ref = &i;
        \\        const tmp = ref.*;
        \\        ref.* += 1;
        \\        break :blk tmp;
        \\    };
        \\    i = blk: {
        \\        const ref = &i;
        \\        const tmp = ref.*;
        \\        ref.* -= 1;
        \\        break :blk tmp;
        \\    };
        \\    u = blk: {
        \\        const ref = &u;
        \\        const tmp = ref.*;
        \\        ref.* +%= 1;
        \\        break :blk tmp;
        \\    };
        \\    u = blk: {
        \\        const ref = &u;
        \\        const tmp = ref.*;
        \\        ref.* -%= 1;
        \\        break :blk tmp;
        \\    };
        \\}
    });

    cases.add("implicit casts",
        \\#include <stdbool.h>
        \\
        \\void fn_int(int x);
        \\void fn_f32(float x);
        \\void fn_f64(double x);
        \\void fn_char(char x);
        \\void fn_bool(bool x);
        \\void fn_ptr(void *x);
        \\
        \\void call() {
        \\    fn_int(3.0f);
        \\    fn_int(3.0);
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
        \\    fn_int((int)&fn_int);
        \\    fn_ptr((void *)42);
        \\}
    , &[_][]const u8{
        \\pub extern fn fn_int(x: c_int) void;
        \\pub extern fn fn_f32(x: f32) void;
        \\pub extern fn fn_f64(x: f64) void;
        \\pub extern fn fn_char(x: u8) void;
        \\pub extern fn fn_bool(x: bool) void;
        \\pub extern fn fn_ptr(x: ?*anyopaque) void;
        \\pub export fn call() void {
        \\    fn_int(@as(c_int, @intFromFloat(3.0)));
        \\    fn_int(@as(c_int, @intFromFloat(3.0)));
        \\    fn_int(@as(c_int, 1094861636));
        \\    fn_f32(@as(f32, @floatFromInt(@as(c_int, 3))));
        \\    fn_f64(@as(f64, @floatFromInt(@as(c_int, 3))));
        \\    fn_char(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, '3'))))));
        \\    fn_char(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, '\x01'))))));
        \\    fn_char(@as(u8, @bitCast(@as(i8, @truncate(@as(c_int, 0))))));
        \\    fn_f32(3.0);
        \\    fn_f64(3.0);
        \\    fn_bool(@as(c_int, 123) != 0);
        \\    fn_bool(@as(c_int, 0) != 0);
        \\    fn_bool(@intFromPtr(&fn_int) != 0);
        \\    fn_int(@as(c_int, @intCast(@intFromPtr(&fn_int))));
        \\    fn_ptr(@as(?*anyopaque, @ptrFromInt(@as(c_int, 42))));
        \\}
    });

    cases.add("function call",
        \\static void bar(void) { }
        \\void foo(int *(baz)(void)) {
        \\    bar();
        \\    baz();
        \\}
    , &[_][]const u8{
        \\pub fn bar() callconv(.C) void {}
        \\pub export fn foo(arg_baz: ?*const fn () callconv(.C) [*c]c_int) void {
        \\    var baz = arg_baz;
        \\    _ = &baz;
        \\    bar();
        \\    _ = baz.?();
        \\}
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
        \\pub const FOO_CHAR = '\x3f';
    });

    cases.add("macro cast",
        \\#include <stdint.h>
        \\int baz(void *arg) { return 0; }
        \\#define FOO(bar) baz((void *)(baz))
        \\#define BAR (void*) a
        \\#define BAZ (uint32_t)(2)
        \\#define a 2
    , &[_][]const u8{
        \\pub inline fn FOO(bar: anytype) @TypeOf(baz(@import("std").zig.c_translation.cast(?*anyopaque, baz))) {
        \\    _ = &bar;
        \\    return baz(@import("std").zig.c_translation.cast(?*anyopaque, baz));
        \\}
        ,
        \\pub const BAR = @import("std").zig.c_translation.cast(?*anyopaque, a);
        ,
        \\pub const BAZ = @import("std").zig.c_translation.cast(u32, @as(c_int, 2));
    });

    cases.add("macro with cast to unsigned short, long, and long long",
        \\#define CURLAUTH_BASIC_BUT_USHORT ((unsigned short) 1)
        \\#define CURLAUTH_BASIC ((unsigned long) 1)
        \\#define CURLAUTH_BASIC_BUT_ULONGLONG ((unsigned long long) 1)
    , &[_][]const u8{
        \\pub const CURLAUTH_BASIC_BUT_USHORT = @import("std").zig.c_translation.cast(c_ushort, @as(c_int, 1));
        \\pub const CURLAUTH_BASIC = @import("std").zig.c_translation.cast(c_ulong, @as(c_int, 1));
        \\pub const CURLAUTH_BASIC_BUT_ULONGLONG = @import("std").zig.c_translation.cast(c_ulonglong, @as(c_int, 1));
    });

    cases.add("macro conditional operator",
        \\ int a, b, c;
        \\#define FOO a ? b : c
    , &[_][]const u8{
        \\pub const FOO = if (a) b else c;
    });

    cases.add("do while as expr",
        \\static void foo(void) {
        \\    if (1)
        \\        do {} while (0);
        \\}
    , &[_][]const u8{
        \\pub fn foo() callconv(.C) void {
        \\    if (true) while (true) {
        \\        if (!false) break;
        \\    };
        \\}
    });

    cases.add("macro comparisons",
        \\#define MIN(a, b) ((b) < (a) ? (b) : (a))
        \\#define MAX(a, b) ((b) > (a) ? (b) : (a))
    , &[_][]const u8{
        \\pub inline fn MIN(a: anytype, b: anytype) @TypeOf(if (b < a) b else a) {
        \\    _ = &a;
        \\    _ = &b;
        \\    return if (b < a) b else a;
        \\}
        ,
        \\pub inline fn MAX(a: anytype, b: anytype) @TypeOf(if (b > a) b else a) {
        \\    _ = &a;
        \\    _ = &b;
        \\    return if (b > a) b else a;
        \\}
    });

    cases.add("nested assignment",
        \\int foo(int *p, int x) {
        \\    return *p++ = x;
        \\}
    , &[_][]const u8{
        \\pub export fn foo(arg_p: [*c]c_int, arg_x: c_int) c_int {
        \\    var p = arg_p;
        \\    _ = &p;
        \\    var x = arg_x;
        \\    _ = &x;
        \\    return blk: {
        \\        const tmp = x;
        \\        (blk_1: {
        \\            const ref = &p;
        \\            const tmp_2 = ref.*;
        \\            ref.* += 1;
        \\            break :blk_1 tmp_2;
        \\        }).* = tmp;
        \\        break :blk tmp;
        \\    };
        \\}
    });

    cases.add("widening and truncating integer casting to different signedness",
        \\unsigned long foo(void) {
        \\    return -1;
        \\}
        \\unsigned short bar(long x) {
        \\    return x;
        \\}
    , &[_][]const u8{
        \\pub export fn foo() c_ulong {
        \\    return @as(c_ulong, @bitCast(@as(c_long, -@as(c_int, 1))));
        \\}
        \\pub export fn bar(arg_x: c_long) c_ushort {
        \\    var x = arg_x;
        \\    _ = &x;
        \\    return @as(c_ushort, @bitCast(@as(c_short, @truncate(x))));
        \\}
    });

    cases.add("arg name aliasing decl which comes after",
        \\void foo(int bar) {
        \\    bar = 2;
        \\}
        \\int bar = 4;
    , &[_][]const u8{
        \\pub export fn foo(arg_bar_1: c_int) void {
        \\    var bar_1 = arg_bar_1;
        \\    _ = &bar_1;
        \\    bar_1 = 2;
        \\}
        \\pub export var bar: c_int = 4;
    });

    cases.add("arg name aliasing macro which comes after",
        \\void foo(int bar) {
        \\    bar = 2;
        \\}
        \\#define bar 4
    , &[_][]const u8{
        \\pub export fn foo(arg_bar_1: c_int) void {
        \\    var bar_1 = arg_bar_1;
        \\    _ = &bar_1;
        \\    bar_1 = 2;
        \\}
        ,
        \\pub const bar = @as(c_int, 4);
    });

    cases.add("don't export inline functions",
        \\inline void a(void) {}
        \\static void b(void) {}
        \\void c(void) {}
        \\static void foo() {}
    , &[_][]const u8{
        \\pub fn a() callconv(.C) void {}
        \\pub fn b() callconv(.C) void {}
        \\pub export fn c() void {}
        \\pub fn foo() callconv(.C) void {}
    });

    cases.add("casting away const and volatile",
        \\void foo(int *a) {}
        \\void bar(const int *a) {
        \\    foo((int *)a);
        \\}
        \\void baz(volatile int *a) {
        \\    foo((int *)a);
        \\}
    , &[_][]const u8{
        \\pub export fn foo(arg_a: [*c]c_int) void {
        \\    var a = arg_a;
        \\    _ = &a;
        \\}
        \\pub export fn bar(arg_a: [*c]const c_int) void {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    foo(@as([*c]c_int, @ptrCast(@volatileCast(@constCast(a)))));
        \\}
        \\pub export fn baz(arg_a: [*c]volatile c_int) void {
        \\    var a = arg_a;
        \\    _ = &a;
        \\    foo(@as([*c]c_int, @ptrCast(@volatileCast(@constCast(a)))));
        \\}
    });

    cases.add("handling of _Bool type",
        \\_Bool foo(_Bool x) {
        \\    _Bool a = x != 1;
        \\    _Bool b = a != 0;
        \\    _Bool c = foo;
        \\    return foo(c != b);
        \\}
    , &[_][]const u8{
        \\pub export fn foo(arg_x: bool) bool {
        \\    var x = arg_x;
        \\    _ = &x;
        \\    var a: bool = @as(c_int, @intFromBool(x)) != @as(c_int, 1);
        \\    _ = &a;
        \\    var b: bool = @as(c_int, @intFromBool(a)) != @as(c_int, 0);
        \\    _ = &b;
        \\    var c: bool = @intFromPtr(&foo) != 0;
        \\    _ = &c;
        \\    return foo(@as(c_int, @intFromBool(c)) != @as(c_int, @intFromBool(b)));
        \\}
    });

    cases.add("Don't make const parameters mutable",
        \\int max(const int x, int y) {
        \\    return (x > y) ? x : y;
        \\}
    , &[_][]const u8{
        \\pub export fn max(x: c_int, arg_y: c_int) c_int {
        \\    _ = &x;
        \\    var y = arg_y;
        \\    _ = &y;
        \\    return if (x > y) x else y;
        \\}
    });

    cases.add("string concatenation in macros",
        \\#define FOO "hello"
        \\#define BAR FOO " world"
        \\#define BAZ "oh, " FOO
    , &[_][]const u8{
        \\pub const FOO = "hello";
        ,
        \\pub const BAR = FOO ++ " world";
        ,
        \\pub const BAZ = "oh, " ++ FOO;
    });

    cases.add("string concatenation in macros: two defines",
        \\#define FOO "hello"
        \\#define BAZ " world"
        \\#define BAR FOO BAZ
    , &[_][]const u8{
        \\pub const FOO = "hello";
        ,
        \\pub const BAZ = " world";
        ,
        \\pub const BAR = FOO ++ BAZ;
    });

    cases.add("string concatenation in macros: two strings",
        \\#define FOO "a" "b"
        \\#define BAR FOO "c"
    , &[_][]const u8{
        \\pub const FOO = "a" ++ "b";
        ,
        \\pub const BAR = FOO ++ "c";
    });

    cases.add("string concatenation in macros: three strings",
        \\#define FOO "a" "b" "c"
    , &[_][]const u8{
        \\pub const FOO = "a" ++ "b" ++ "c";
    });

    cases.add("multibyte character literals",
        \\#define FOO 'abcd'
    , &[_][]const u8{
        \\pub const FOO = 0x61626364;
    });

    cases.add("Make sure casts are grouped",
        \\typedef struct
        \\{
        \\    int i;
        \\}
        \\*_XPrivDisplay;
        \\typedef struct _XDisplay Display;
        \\#define DefaultScreen(dpy) (((_XPrivDisplay)(dpy))->default_screen)
        \\
    , &[_][]const u8{
        \\pub inline fn DefaultScreen(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.default_screen) {
        \\    _ = &dpy;
        \\    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.default_screen;
        \\}
    });

    cases.add("macro integer literal casts",
        \\#define NULL ((void*)0)
        \\#define FOO ((int)0x8000)
    , &[_][]const u8{
        \\pub const NULL = @import("std").zig.c_translation.cast(?*anyopaque, @as(c_int, 0));
        ,
        \\pub const FOO = @import("std").zig.c_translation.cast(c_int, @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x8000, .hex));
    });

    if (builtin.abi == .msvc) {
        cases.add("nameless struct fields",
            \\typedef struct NAMED
            \\{
            \\    long name;
            \\} NAMED;
            \\
            \\typedef struct ONENAMEWITHSTRUCT
            \\{
            \\    NAMED;
            \\    long b;
            \\} ONENAMEWITHSTRUCT;
        , &[_][]const u8{
            \\pub const struct_NAMED = extern struct {
            \\    name: c_long = @import("std").mem.zeroes(c_long),
            \\};
            \\pub const NAMED = struct_NAMED;
            \\pub const struct_ONENAMEWITHSTRUCT = extern struct {
            \\    unnamed_0: struct_NAMED =  = @import("std").mem.zeroes(struct_NAMED),
            \\    b: c_long = @import("std").mem.zeroes(c_long),
            \\};
        });
    } else {
        cases.add("nameless struct fields",
            \\typedef struct NAMED
            \\{
            \\    long name;
            \\} NAMED;
            \\
            \\typedef struct ONENAMEWITHSTRUCT
            \\{
            \\    NAMED;
            \\    long b;
            \\} ONENAMEWITHSTRUCT;
        , &[_][]const u8{
            \\pub const struct_NAMED = extern struct {
            \\    name: c_long = @import("std").mem.zeroes(c_long),
            \\};
            \\pub const NAMED = struct_NAMED;
            \\pub const struct_ONENAMEWITHSTRUCT = extern struct {
            \\    b: c_long = @import("std").mem.zeroes(c_long),
            \\};
        });
    }

    cases.add("integer literal promotion",
        \\#define GUARANTEED_TO_FIT_1 1024
        \\#define GUARANTEED_TO_FIT_2 10241024L
        \\#define GUARANTEED_TO_FIT_3 20482048LU
        \\#define MAY_NEED_PROMOTION_1 10241024
        \\#define MAY_NEED_PROMOTION_2 307230723072L
        \\#define MAY_NEED_PROMOTION_3 819281928192LU
        \\#define MAY_NEED_PROMOTION_HEX 0x80000000
        \\#define MAY_NEED_PROMOTION_OCT 020000000000
    , &[_][]const u8{
        \\pub const GUARANTEED_TO_FIT_1 = @as(c_int, 1024);
        \\pub const GUARANTEED_TO_FIT_2 = @as(c_long, 10241024);
        \\pub const GUARANTEED_TO_FIT_3 = @as(c_ulong, 20482048);
        \\pub const MAY_NEED_PROMOTION_1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 10241024, .decimal);
        \\pub const MAY_NEED_PROMOTION_2 = @import("std").zig.c_translation.promoteIntLiteral(c_long, 307230723072, .decimal);
        \\pub const MAY_NEED_PROMOTION_3 = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 819281928192, .decimal);
        \\pub const MAY_NEED_PROMOTION_HEX = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x80000000, .hex);
        \\pub const MAY_NEED_PROMOTION_OCT = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0o20000000000, .octal);
    });

    cases.add("demote un-implemented builtins",
        \\#define FOO(X) __builtin_alloca_with_align((X), 8)
    , &[_][]const u8{
        \\pub const FOO = @compileError("unable to translate macro: undefined identifier `__builtin_alloca_with_align`");
    });

    cases.add("null sentinel arrays when initialized from string literal. Issue #8256",
        \\#include <stdint.h>
        \\char zero[0] = "abc";
        \\uint32_t zero_w[0] = U"💯💯💯";
        \\char empty_incomplete[] = "";
        \\uint32_t empty_incomplete_w[] = U"";
        \\char empty_constant[100] = "";
        \\uint32_t empty_constant_w[100] = U"";
        \\char incomplete[] = "abc";
        \\uint32_t incomplete_w[] = U"💯💯💯";
        \\char truncated[1] = "abc";
        \\uint32_t truncated_w[1] = U"💯💯💯";
        \\char extend[5] = "a";
        \\uint32_t extend_w[5] = U"💯";
        \\char no_null[3] = "abc";
        \\uint32_t no_null_w[3] = U"💯💯💯";
    , &[_][]const u8{
        \\pub export var zero: [0]u8 = [0]u8{};
        \\pub export var zero_w: [0]u32 = [0]u32{};
        \\pub export var empty_incomplete: [1]u8 = [1]u8{0} ** 1;
        \\pub export var empty_incomplete_w: [1]u32 = [1]u32{0} ** 1;
        \\pub export var empty_constant: [100]u8 = [1]u8{0} ** 100;
        \\pub export var empty_constant_w: [100]u32 = [1]u32{0} ** 100;
        \\pub export var incomplete: [3:0]u8 = "abc".*;
        \\pub export var incomplete_w: [3:0]u32 = [3:0]u32{
        \\    '\u{1f4af}',
        \\    '\u{1f4af}',
        \\    '\u{1f4af}',
        \\};
        \\pub export var truncated: [1]u8 = "abc"[0..1].*;
        \\pub export var truncated_w: [1]u32 = [1]u32{
        \\    '\u{1f4af}',
        \\};
        \\pub export var extend: [5]u8 = "a"[0..1].* ++ [1]u8{0} ** 4;
        \\pub export var extend_w: [5]u32 = [1]u32{
        \\    '\u{1f4af}',
        \\} ++ [1]u32{0} ** 4;
        \\pub export var no_null: [3]u8 = "abc".*;
        \\pub export var no_null_w: [3]u32 = [3]u32{
        \\    '\u{1f4af}',
        \\    '\u{1f4af}',
        \\    '\u{1f4af}',
        \\};
    });

    cases.add("global assembly",
        \\__asm__(".globl func\n\t"
        \\        ".type func, @function\n\t"
        \\        "func:\n\t"
        \\        ".cfi_startproc\n\t"
        \\        "movl $42, %eax\n\t"
        \\        "ret\n\t"
        \\        ".cfi_endproc");
    , &[_][]const u8{
        \\comptime {
        \\    asm (".globl func\n\t.type func, @function\n\tfunc:\n\t.cfi_startproc\n\tmovl $42, %eax\n\tret\n\t.cfi_endproc");
        \\}
    });

    cases.add("Demote function that initializes opaque struct",
        \\struct my_struct {
        \\    unsigned a: 15;
        \\    unsigned: 2;
        \\    unsigned b: 15;
        \\};
        \\void initialize(void) {
        \\    struct my_struct S = {.a = 1, .b = 2};
        \\}
    , &[_][]const u8{
        \\warning: local variable has opaque type
        ,
        \\warning: unable to translate function, demoted to extern
        \\pub extern fn initialize() void;
    });

    cases.add("Demote function that dereferences opaque type",
        \\struct my_struct {
        \\    unsigned a: 1;
        \\};
        \\void deref(struct my_struct *s) {
        \\    *s;
        \\}
    , &[_][]const u8{
        \\warning: cannot dereference opaque type
        ,
        \\warning: unable to translate function, demoted to extern
        \\pub extern fn deref(arg_s: ?*struct_my_struct) void;
    });

    cases.add("Demote function that dereference types that contain opaque type",
        \\struct inner {
        \\    _Atomic int a;
        \\};
        \\struct outer {
        \\    int thing;
        \\    struct inner sub_struct;
        \\};
        \\void deref(struct outer *s) {
        \\    *s;
        \\}
    , &[_][]const u8{
        \\pub const struct_inner = opaque {};
        ,
        \\pub const struct_outer = extern struct {
        \\    thing: c_int = @import("std").mem.zeroes(c_int),
        \\    sub_struct: struct_inner = @import("std").mem.zeroes(struct_inner),
        \\};
        ,
        \\warning: unable to translate function, demoted to extern
        ,
        \\pub extern fn deref(arg_s: ?*struct_outer) void;
    });

    cases.add("Function prototype declared within function",
        \\int foo(void) {
        \\    extern int bar(int, int);
        \\    return bar(1, 2);
        \\}
    , &[_][]const u8{
        \\pub extern fn bar(c_int, c_int) c_int;
        \\pub export fn foo() c_int {
        \\    return bar(@as(c_int, 1), @as(c_int, 2));
        \\}
    });

    cases.add("static local variable zero-initialized if no initializer",
        \\struct FOO {int x; int y;};
        \\int bar(void) {
        \\    static struct FOO foo;
        \\    return foo.x;
        \\}
    , &[_][]const u8{
        \\pub const struct_FOO = extern struct {
        \\    x: c_int = @import("std").mem.zeroes(c_int),
        \\    y: c_int = @import("std").mem.zeroes(c_int),
        \\};
        \\pub export fn bar() c_int {
        \\    const foo = struct {
        \\        var static: struct_FOO = @import("std").mem.zeroes(struct_FOO);
        \\    };
        \\    _ = &foo;
        \\    return foo.static.x;
        \\}
    });

    cases.add("macro with nontrivial cast",
        \\#define MAP_FAILED ((void *) -1)
        \\typedef long long LONG_PTR;
        \\#define INVALID_HANDLE_VALUE ((void *)(LONG_PTR)-1)
    , &[_][]const u8{
        \\pub const MAP_FAILED = @import("std").zig.c_translation.cast(?*anyopaque, -@as(c_int, 1));
        \\pub const INVALID_HANDLE_VALUE = @import("std").zig.c_translation.cast(?*anyopaque, @import("std").zig.c_translation.cast(LONG_PTR, -@as(c_int, 1)));
    });

    cases.add("discard unused local variables and function parameters",
        \\#define FOO(A, B) (A)
        \\int bar(int x, int y) {
        \\   return x;
        \\}
    , &[_][]const u8{
        \\pub export fn bar(arg_x: c_int, arg_y: c_int) c_int {
        \\    var x = arg_x;
        \\    _ = &x;
        \\    var y = arg_y;
        \\    _ = &y;
        \\    return x;
        \\}
        ,
        \\pub inline fn FOO(A: anytype, B: anytype) @TypeOf(A) {
        \\    _ = &A;
        \\    _ = &B;
        \\    return A;
        \\}
    });

    cases.add("Use @ syntax for bare underscore identifier in macro or public symbol",
        \\#define FOO _
        \\int _ = 42;
    , &[_][]const u8{
        \\pub const FOO = @"_";
        ,
        \\pub export var @"_": c_int = 42;
    });

    cases.add("Macro matching",
        \\#define FOO(X) (X ## U)
    , &[_][]const u8{
        \\pub const FOO = @import("std").zig.c_translation.Macros.U_SUFFIX;
    });

    cases.add("Simple array access of pointer with non-negative integer constant",
        \\void foo(int *p) {
        \\    p[0];
        \\    p[1];
        \\}
    , &[_][]const u8{
        \\_ = p[@as(c_uint, @intCast(@as(c_int, 0)))];
        ,
        \\_ = p[@as(c_uint, @intCast(@as(c_int, 1)))];
    });

    cases.add("Undefined macro identifier",
        \\#define FOO BAR
    , &[_][]const u8{
        \\pub const FOO = @compileError("unable to translate macro: undefined identifier `BAR`");
    });

    cases.add("Macro redefines builtin",
        \\#define FOO __builtin_popcount
    , &[_][]const u8{
        \\pub const FOO = __builtin_popcount;
    });

    cases.add("Only consider public decls in `isBuiltinDefined`",
        \\#define FOO std
    , &[_][]const u8{
        \\pub const FOO = @compileError("unable to translate macro: undefined identifier `std`");
    });

    cases.add("Macro without a value",
        \\#define FOO
    , &[_][]const u8{
        \\pub const FOO = "";
    });

    cases.add("leading zeroes",
        \\#define O_RDONLY  00
        \\#define HELLO 000
        \\#define ZERO 0
        \\#define WORLD 00000123
    , &[_][]const u8{
        \\pub const O_RDONLY = @as(c_int, 0o0);
        \\pub const HELLO = @as(c_int, 0o00);
        \\pub const ZERO = @as(c_int, 0);
        \\pub const WORLD = @as(c_int, 0o0000123);
    });

    cases.add("Assign expression from bool to int",
        \\void foo(void) {
        \\    int a;
        \\    if (a = 1 > 0) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var a: c_int = undefined;
        \\    _ = &a;
        \\    if ((blk: {
        \\        const tmp = @intFromBool(@as(c_int, 1) > @as(c_int, 0));
        \\        a = tmp;
        \\        break :blk tmp;
        \\    }) != 0) {}
        \\}
    });

    if (builtin.os.tag == .windows) {
        cases.add("Pointer subtraction with typedef",
            \\typedef char* S;
            \\void foo() {
            \\    S a, b;
            \\    long long c = a - b;
            \\}
        , &[_][]const u8{
            \\pub export fn foo() void {
            \\    var a: S = undefined;
            \\    _ = &a;
            \\    var b: S = undefined;
            \\    _ = &b;
            \\    var c: c_longlong = @divExact(@as(c_longlong, @bitCast(@intFromPtr(a) -% @intFromPtr(b))), @sizeOf(u8));
            \\    _ = &c;
            \\}
        });
    } else {
        cases.add("Pointer subtraction with typedef",
            \\typedef char* S;
            \\void foo() {
            \\    S a, b;
            \\    long c = a - b;
            \\}
        , &[_][]const u8{
            \\pub export fn foo() void {
            \\    var a: S = undefined;
            \\    _ = &a;
            \\    var b: S = undefined;
            \\    _ = &b;
            \\    var c: c_long = @divExact(@as(c_long, @bitCast(@intFromPtr(a) -% @intFromPtr(b))), @sizeOf(u8));
            \\    _ = &c;
            \\}
        });
    }

    cases.add("extern array of unknown length",
        \\extern int foo[];
    , &[_][]const u8{
        \\const foo: [*c]c_int = @extern([*c]c_int, .{
        \\    .name = "foo",
        \\});
    });

    cases.add("string array initializer",
        \\static const char foo[] = {"bar"};
    , &[_][]const u8{
        \\pub const foo: [3:0]u8 = "bar";
    });

    cases.add("worst-case assign from mangle prefix",
        \\void foo() {
        \\    int n, tmp = 1;
        \\    if (n = tmp) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var n: c_int = undefined;
        \\    _ = &n;
        \\    var tmp: c_int = 1;
        \\    _ = &tmp;
        \\    if ((blk: {
        \\        const tmp_1 = tmp;
        \\        n = tmp_1;
        \\        break :blk tmp_1;
        \\    }) != 0) {}
        \\}
    });

    cases.add("worst-case assign to mangle prefix",
        \\void foo() {
        \\    int tmp, n = 1;
        \\    if (tmp = n) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var tmp: c_int = undefined;
        \\    _ = &tmp;
        \\    var n: c_int = 1;
        \\    _ = &n;
        \\    if ((blk: {
        \\        const tmp_1 = n;
        \\        tmp = tmp_1;
        \\        break :blk tmp_1;
        \\    }) != 0) {}
        \\}
    });

    cases.add("worst-case precrement mangle prefix",
        \\void foo() {
        \\    int n, ref = 1;
        \\    if (n = ++ref) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var n: c_int = undefined;
        \\    _ = &n;
        \\    var ref: c_int = 1;
        \\    _ = &ref;
        \\    if ((blk: {
        \\        const tmp = blk_1: {
        \\            const ref_2 = &ref;
        \\            ref_2.* += 1;
        \\            break :blk_1 ref_2.*;
        \\        };
        \\        n = tmp;
        \\        break :blk tmp;
        \\    }) != 0) {}
        \\}
    });

    cases.add("worst-case postcrement mangle prefix",
        \\void foo() {
        \\    int n, ref = 1;
        \\    if (n = ref++) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var n: c_int = undefined;
        \\    _ = &n;
        \\    var ref: c_int = 1;
        \\    _ = &ref;
        \\    if ((blk: {
        \\        const tmp = blk_1: {
        \\            const ref_2 = &ref;
        \\            const tmp_3 = ref_2.*;
        \\            ref_2.* += 1;
        \\            break :blk_1 tmp_3;
        \\        };
        \\        n = tmp;
        \\        break :blk tmp;
        \\    }) != 0) {}
        \\}
    });

    cases.add("worst-case compound assign from mangle prefix",
        \\void foo() {
        \\    int n, ref = 1;
        \\    if (n += ref) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var n: c_int = undefined;
        \\    _ = &n;
        \\    var ref: c_int = 1;
        \\    _ = &ref;
        \\    if ((blk: {
        \\        const ref_1 = &n;
        \\        ref_1.* += ref;
        \\        break :blk ref_1.*;
        \\    }) != 0) {}
        \\}
    });

    cases.add("worst-case compound assign to mangle prefix",
        \\void foo() {
        \\    int ref, n = 1;
        \\    if (ref += n) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var ref: c_int = undefined;
        \\    _ = &ref;
        \\    var n: c_int = 1;
        \\    _ = &n;
        \\    if ((blk: {
        \\        const ref_1 = &ref;
        \\        ref_1.* += n;
        \\        break :blk ref_1.*;
        \\    }) != 0) {}
        \\}
    });

    cases.add("binary conditional operator where condition is the mangle prefix",
        \\void foo() {
        \\    int f = 1;
        \\    int n, cond_temp = 1;
        \\    if (n = (cond_temp)?:(f)) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var f: c_int = 1;
        \\    _ = &f;
        \\    var n: c_int = undefined;
        \\    _ = &n;
        \\    var cond_temp: c_int = 1;
        \\    _ = &cond_temp;
        \\    if ((blk: {
        \\        const tmp = blk_1: {
        \\            const cond_temp_2 = cond_temp;
        \\            break :blk_1 if (cond_temp_2 != 0) cond_temp_2 else f;
        \\        };
        \\        n = tmp;
        \\        break :blk tmp;
        \\    }) != 0) {}
        \\}
    });

    cases.add("binary conditional operator where false_expr is the mangle prefix",
        \\void foo() {
        \\    int cond_temp = 1;
        \\    int n, f = 1;
        \\    if (n = (f)?:(cond_temp)) {}
        \\}
    , &[_][]const u8{
        \\pub export fn foo() void {
        \\    var cond_temp: c_int = 1;
        \\    _ = &cond_temp;
        \\    var n: c_int = undefined;
        \\    _ = &n;
        \\    var f: c_int = 1;
        \\    _ = &f;
        \\    if ((blk: {
        \\        const tmp = blk_1: {
        \\            const cond_temp_2 = f;
        \\            break :blk_1 if (cond_temp_2 != 0) cond_temp_2 else cond_temp;
        \\        };
        \\        n = tmp;
        \\        break :blk tmp;
        \\    }) != 0) {}
        \\}
    });

    cases.add("macro using argument as struct name is not translated",
        \\#define FOO(x) struct x
    , &[_][]const u8{
        \\pub const FOO = @compileError("unable to translate macro: untranslatable usage of arg `x`");
    });

    cases.add("unsupport declare statement at the last of a compound statement which belongs to a statement expr",
        \\void somefunc(void) {
        \\  int y;
        \\  (void)({y=1; _Static_assert(1);});
        \\}
    , &[_][]const u8{
        \\pub export fn somefunc() void {
        \\    var y: c_int = undefined;
        \\    _ = &y;
        \\    _ = blk: {
        \\        y = 1;
        \\    };
        \\}
    });
}
