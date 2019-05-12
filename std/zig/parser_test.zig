test "temporary trivial example" {
    try testCanonical(
        \\const x = true;
        \\
    );
}

test "zig fmt: allowzero pointer" {
    try testCanonical(
        \\const T = [*]allowzero const u8;
        \\
    );
}

test "zig fmt: enum literal" {
    try testCanonical(
        \\const x = .hi;
        \\
    );
}

test "zig fmt: character literal larger than u8" {
    try testCanonical(
        \\const x = '\U01f4a9';
        \\
    );
}

test "zig fmt: infix operator and then multiline string literal" {
    try testCanonical(
        \\const x = "" ++
        \\    \\ hi
        \\;
        \\
    );
}

test "zig fmt: C pointers" {
    try testCanonical(
        \\const Ptr = [*c]i32;
        \\
    );
}

test "zig fmt: threadlocal" {
    try testCanonical(
        \\threadlocal var x: i32 = 1234;
        \\
    );
}

test "zig fmt: linksection" {
    try testCanonical(
        \\export var aoeu: u64 linksection(".text.derp") = 1234;
        \\export nakedcc fn _start() linksection(".text.boot") noreturn {}
        \\
    );
}

test "zig fmt: shebang line" {
    try testCanonical(
        \\#!/usr/bin/env zig
        \\pub fn main() void {}
        \\
    );
}

test "zig fmt: correctly move doc comments on struct fields" {
    try testTransform(
        \\pub const section_64 = extern struct {
        \\    sectname: [16]u8, /// name of this section
        \\    segname: [16]u8,  /// segment this section goes in
        \\};
    ,
        \\pub const section_64 = extern struct {
        \\    /// name of this section
        \\    sectname: [16]u8,
        \\    /// segment this section goes in
        \\    segname: [16]u8,
        \\};
        \\
    );
}

test "zig fmt: doc comments on param decl" {
    try testCanonical(
        \\pub const Allocator = struct {
        \\    shrinkFn: fn (
        \\        self: *Allocator,
        \\        /// Guaranteed to be the same as what was returned from most recent call to
        \\        /// `allocFn`, `reallocFn`, or `shrinkFn`.
        \\        old_mem: []u8,
        \\        /// Guaranteed to be the same as what was returned from most recent call to
        \\        /// `allocFn`, `reallocFn`, or `shrinkFn`.
        \\        old_alignment: u29,
        \\        /// Guaranteed to be less than or equal to `old_mem.len`.
        \\        new_byte_count: usize,
        \\        /// Guaranteed to be less than or equal to `old_alignment`.
        \\        new_alignment: u29,
        \\    ) []u8,
        \\};
        \\
    );
}

test "zig fmt: preserve space between async fn definitions" {
    try testCanonical(
        \\async fn a() void {}
        \\
        \\async fn b() void {}
        \\
    );
}

test "zig fmt: comment to disable/enable zig fmt first" {
    try testCanonical(
        \\// Test trailing comma syntax
        \\// zig fmt: off
        \\
        \\const struct_trailing_comma = struct { x: i32, y: i32, };
    );
}

test "zig fmt: comment to disable/enable zig fmt" {
    try testTransform(
        \\const  a  =  b;
        \\// zig fmt: off
        \\const  c  =  d;
        \\// zig fmt: on
        \\const  e  =  f;
    ,
        \\const a = b;
        \\// zig fmt: off
        \\const  c  =  d;
        \\// zig fmt: on
        \\const e = f;
        \\
    );
}

test "zig fmt: pointer of unknown length" {
    try testCanonical(
        \\fn foo(ptr: [*]u8) void {}
        \\
    );
}

test "zig fmt: spaces around slice operator" {
    try testCanonical(
        \\var a = b[c..d];
        \\var a = b[c + 1 .. d];
        \\var a = b[c + 1 ..];
        \\var a = b[c .. d + 1];
        \\var a = b[c.a..d.e];
        \\
    );
}

test "zig fmt: async call in if condition" {
    try testCanonical(
        \\comptime {
        \\    if (async<a> b()) {
        \\        a();
        \\    }
        \\}
        \\
    );
}

test "zig fmt: 2nd arg multiline string" {
    try testCanonical(
        \\comptime {
        \\    cases.addAsm("hello world linux x86_64",
        \\        \\.text
        \\    , "Hello, world!\n");
        \\}
        \\
    );
}

test "zig fmt: if condition wraps" {
    try testTransform(
        \\comptime {
        \\    if (cond and
        \\        cond) {
        \\        return x;
        \\    }
        \\    while (cond and
        \\        cond) {
        \\        return x;
        \\    }
        \\    if (a == b and
        \\        c) {
        \\        a = b;
        \\    }
        \\    while (a == b and
        \\        c) {
        \\        a = b;
        \\    }
        \\    if ((cond and
        \\        cond)) {
        \\        return x;
        \\    }
        \\    while ((cond and
        \\        cond)) {
        \\        return x;
        \\    }
        \\    var a = if (a) |*f| x: {
        \\        break :x &a.b;
        \\    } else |err| err;
        \\}
    ,
        \\comptime {
        \\    if (cond and
        \\        cond)
        \\    {
        \\        return x;
        \\    }
        \\    while (cond and
        \\        cond)
        \\    {
        \\        return x;
        \\    }
        \\    if (a == b and
        \\        c)
        \\    {
        \\        a = b;
        \\    }
        \\    while (a == b and
        \\        c)
        \\    {
        \\        a = b;
        \\    }
        \\    if ((cond and
        \\        cond))
        \\    {
        \\        return x;
        \\    }
        \\    while ((cond and
        \\        cond))
        \\    {
        \\        return x;
        \\    }
        \\    var a = if (a) |*f| x: {
        \\        break :x &a.b;
        \\    } else |err| err;
        \\}
        \\
    );
}

test "zig fmt: if condition has line break but must not wrap" {
    try testCanonical(
        \\comptime {
        \\    if (self.user_input_options.put(name, UserInputOption{
        \\        .name = name,
        \\        .used = false,
        \\    }) catch unreachable) |*prev_value| {
        \\        foo();
        \\        bar();
        \\    }
        \\    if (put(
        \\        a,
        \\        b,
        \\    )) {
        \\        foo();
        \\    }
        \\}
        \\
    );
}

test "zig fmt: same-line doc comment on variable declaration" {
    try testTransform(
        \\pub const MAP_ANONYMOUS = 0x1000; /// allocated from memory, swap space
        \\pub const MAP_FILE = 0x0000; /// map from file (default)
        \\
        \\pub const EMEDIUMTYPE = 124; /// Wrong medium type
        \\
        \\// nameserver query return codes
        \\pub const ENSROK = 0; /// DNS server returned answer with no data
    ,
        \\/// allocated from memory, swap space
        \\pub const MAP_ANONYMOUS = 0x1000;
        \\/// map from file (default)
        \\pub const MAP_FILE = 0x0000;
        \\
        \\/// Wrong medium type
        \\pub const EMEDIUMTYPE = 124;
        \\
        \\// nameserver query return codes
        \\/// DNS server returned answer with no data
        \\pub const ENSROK = 0;
        \\
    );
}

test "zig fmt: if-else with comment before else" {
    try testCanonical(
        \\comptime {
        \\    // cexp(finite|nan +- i inf|nan) = nan + i nan
        \\    if ((hx & 0x7fffffff) != 0x7f800000) {
        \\        return Complex(f32).new(y - y, y - y);
        \\    } // cexp(-inf +- i inf|nan) = 0 + i0
        \\    else if (hx & 0x80000000 != 0) {
        \\        return Complex(f32).new(0, 0);
        \\    } // cexp(+inf +- i inf|nan) = inf + i nan
        \\    else {
        \\        return Complex(f32).new(x, y - y);
        \\    }
        \\}
        \\
    );
}

test "zig fmt: respect line breaks in if-else" {
    try testCanonical(
        \\comptime {
        \\    return if (cond) a else b;
        \\    return if (cond)
        \\        a
        \\    else
        \\        b;
        \\    return if (cond)
        \\        a
        \\    else if (cond)
        \\        b
        \\    else
        \\        c;
        \\}
        \\
    );
}

test "zig fmt: respect line breaks after infix operators" {
    try testCanonical(
        \\comptime {
        \\    self.crc =
        \\        lookup_tables[0][p[7]] ^
        \\        lookup_tables[1][p[6]] ^
        \\        lookup_tables[2][p[5]] ^
        \\        lookup_tables[3][p[4]] ^
        \\        lookup_tables[4][@truncate(u8, self.crc >> 24)] ^
        \\        lookup_tables[5][@truncate(u8, self.crc >> 16)] ^
        \\        lookup_tables[6][@truncate(u8, self.crc >> 8)] ^
        \\        lookup_tables[7][@truncate(u8, self.crc >> 0)];
        \\}
        \\
    );
}

test "zig fmt: fn decl with trailing comma" {
    try testTransform(
        \\fn foo(a: i32, b: i32,) void {}
    ,
        \\fn foo(
        \\    a: i32,
        \\    b: i32,
        \\) void {}
        \\
    );
}

test "zig fmt: var_args with trailing comma" {
    try testCanonical(
        \\pub fn add(
        \\    a: ...,
        \\) void {}
        \\
    );
}

test "zig fmt: enum decl with no trailing comma" {
    try testTransform(
        \\const StrLitKind = enum {Normal, C};
    ,
        \\const StrLitKind = enum {
        \\    Normal,
        \\    C,
        \\};
        \\
    );
}

test "zig fmt: switch comment before prong" {
    try testCanonical(
        \\comptime {
        \\    switch (a) {
        \\        // hi
        \\        0 => {},
        \\    }
        \\}
        \\
    );
}

test "zig fmt: struct literal no trailing comma" {
    try testTransform(
        \\const a = foo{ .x = 1, .y = 2 };
        \\const a = foo{ .x = 1,
        \\    .y = 2 };
    ,
        \\const a = foo{ .x = 1, .y = 2 };
        \\const a = foo{
        \\    .x = 1,
        \\    .y = 2,
        \\};
        \\
    );
}

test "zig fmt: struct literal containing a multiline expression" {
    try testTransform(
        \\const a = A{ .x = if (f1()) 10 else 20 };
        \\const a = A{ .x = if (f1()) 10 else 20, };
        \\const a = A{ .x = if (f1())
        \\    10 else 20 };
        \\const a = A{ .x = if (f1()) 10 else 20, .y = f2() + 100 };
        \\const a = A{ .x = if (f1()) 10 else 20, .y = f2() + 100, };
        \\const a = A{ .x = if (f1())
        \\    10 else 20};
        \\const a = A{ .x = switch(g) {0 => "ok", else => "no"} };
        \\
    ,
        \\const a = A{ .x = if (f1()) 10 else 20 };
        \\const a = A{
        \\    .x = if (f1()) 10 else 20,
        \\};
        \\const a = A{
        \\    .x = if (f1())
        \\        10
        \\    else
        \\        20,
        \\};
        \\const a = A{ .x = if (f1()) 10 else 20, .y = f2() + 100 };
        \\const a = A{
        \\    .x = if (f1()) 10 else 20,
        \\    .y = f2() + 100,
        \\};
        \\const a = A{
        \\    .x = if (f1())
        \\        10
        \\    else
        \\        20,
        \\};
        \\const a = A{
        \\    .x = switch (g) {
        \\        0 => "ok",
        \\        else => "no",
        \\    },
        \\};
        \\
    );
}

test "zig fmt: array literal with hint" {
    try testTransform(
        \\const a = []u8{
        \\    1, 2, //
        \\    3,
        \\    4,
        \\    5,
        \\    6,
        \\    7 };
        \\const a = []u8{
        \\    1, 2, //
        \\    3,
        \\    4,
        \\    5,
        \\    6,
        \\    7, 8 };
        \\const a = []u8{
        \\    1, 2, //
        \\    3,
        \\    4,
        \\    5,
        \\    6, // blah
        \\    7, 8 };
        \\const a = []u8{
        \\    1, 2, //
        \\    3, //
        \\    4,
        \\    5,
        \\    6,
        \\    7 };
        \\const a = []u8{
        \\    1,
        \\    2,
        \\    3, 4, //
        \\    5, 6, //
        \\    7, 8, //
        \\};
    ,
        \\const a = []u8{
        \\    1, 2,
        \\    3, 4,
        \\    5, 6,
        \\    7,
        \\};
        \\const a = []u8{
        \\    1, 2,
        \\    3, 4,
        \\    5, 6,
        \\    7, 8,
        \\};
        \\const a = []u8{
        \\    1, 2,
        \\    3, 4,
        \\    5, 6, // blah
        \\    7, 8,
        \\};
        \\const a = []u8{
        \\    1, 2,
        \\    3, //
        \\        4,
        \\    5, 6,
        \\    7,
        \\};
        \\const a = []u8{
        \\    1,
        \\    2,
        \\    3,
        \\    4,
        \\    5,
        \\    6,
        \\    7,
        \\    8,
        \\};
        \\
    );
}

test "zig fmt: array literal veritical column alignment" {
    try testTransform(
        \\const a = []u8{
        \\    1000, 200,
        \\    30, 4,
        \\    50000, 60
        \\};
        \\const a = []u8{0,   1, 2, 3, 40,
        \\    4,5,600,7,
        \\           80,
        \\    9, 10, 11, 0, 13, 14, 15};
        \\
    ,
        \\const a = []u8{
        \\    1000,  200,
        \\    30,    4,
        \\    50000, 60,
        \\};
        \\const a = []u8{
        \\    0,  1,  2,   3, 40,
        \\    4,  5,  600, 7, 80,
        \\    9,  10, 11,  0, 13,
        \\    14, 15,
        \\};
        \\
    );
}

test "zig fmt: multiline string with backslash at end of line" {
    try testCanonical(
        \\comptime {
        \\    err(
        \\        \\\
        \\    );
        \\}
        \\
    );
}

test "zig fmt: multiline string parameter in fn call with trailing comma" {
    try testCanonical(
        \\fn foo() void {
        \\    try stdout.print(
        \\        \\ZIG_CMAKE_BINARY_DIR {}
        \\        \\ZIG_C_HEADER_FILES   {}
        \\        \\ZIG_DIA_GUIDS_LIB    {}
        \\        \\
        \\    ,
        \\        std.cstr.toSliceConst(c.ZIG_CMAKE_BINARY_DIR),
        \\        std.cstr.toSliceConst(c.ZIG_CXX_COMPILER),
        \\        std.cstr.toSliceConst(c.ZIG_DIA_GUIDS_LIB),
        \\    );
        \\}
        \\
    );
}

test "zig fmt: trailing comma on fn call" {
    try testCanonical(
        \\comptime {
        \\    var module = try Module.create(
        \\        allocator,
        \\        zig_lib_dir,
        \\        full_cache_dir,
        \\    );
        \\}
        \\
    );
}

test "zig fmt: multi line arguments without last comma" {
    try testTransform(
        \\pub fn foo(
        \\    a: usize,
        \\    b: usize,
        \\    c: usize,
        \\    d: usize
        \\) usize {
        \\    return a + b + c + d;
        \\}
        \\
    ,
        \\pub fn foo(a: usize, b: usize, c: usize, d: usize) usize {
        \\    return a + b + c + d;
        \\}
        \\
    );
}

test "zig fmt: empty block with only comment" {
    try testCanonical(
        \\comptime {
        \\    {
        \\        // comment
        \\    }
        \\}
        \\
    );
}

test "zig fmt: no trailing comma on struct decl" {
    try testTransform(
        \\const RoundParam = struct {
        \\    k: usize, s: u32, t: u32
        \\};
    ,
        \\const RoundParam = struct {
        \\    k: usize,
        \\    s: u32,
        \\    t: u32,
        \\};
        \\
    );
}

test "zig fmt: extra newlines at the end" {
    try testTransform(
        \\const a = b;
        \\
        \\
        \\
    ,
        \\const a = b;
        \\
    );
}

test "zig fmt: simple asm" {
    try testTransform(
        \\comptime {
        \\    asm volatile (
        \\        \\.globl aoeu;
        \\        \\.type aoeu, @function;
        \\        \\.set aoeu, derp;
        \\    );
        \\
        \\    asm ("not real assembly"
        \\        :[a] "x" (x),);
        \\    asm ("not real assembly"
        \\        :[a] "x" (->i32),:[a] "x" (1),);
        \\    asm ("still not real assembly"
        \\        :::"a","b",);
        \\}
    ,
        \\comptime {
        \\    asm volatile (
        \\        \\.globl aoeu;
        \\        \\.type aoeu, @function;
        \\        \\.set aoeu, derp;
        \\    );
        \\
        \\    asm ("not real assembly"
        \\        : [a] "x" (x)
        \\    );
        \\    asm ("not real assembly"
        \\        : [a] "x" (-> i32)
        \\        : [a] "x" (1)
        \\    );
        \\    asm ("still not real assembly"
        \\        :
        \\        :
        \\        : "a", "b"
        \\    );
        \\}
        \\
    );
}

test "zig fmt: nested struct literal with one item" {
    try testCanonical(
        \\const a = foo{
        \\    .item = bar{ .a = b },
        \\};
        \\
    );
}

test "zig fmt: switch cases trailing comma" {
    try testTransform(
        \\fn switch_cases(x: i32) void {
        \\    switch (x) {
        \\        1,2,3 => {},
        \\        4,5, => {},
        \\        6... 8, => {},
        \\        else => {},
        \\    }
        \\}
    ,
        \\fn switch_cases(x: i32) void {
        \\    switch (x) {
        \\        1, 2, 3 => {},
        \\        4,
        \\        5,
        \\        => {},
        \\        6...8 => {},
        \\        else => {},
        \\    }
        \\}
        \\
    );
}

test "zig fmt: slice align" {
    try testCanonical(
        \\const A = struct {
        \\    items: []align(A) T,
        \\};
        \\
    );
}

test "zig fmt: add trailing comma to array literal" {
    try testTransform(
        \\comptime {
        \\    return []u16{'m', 's', 'y', 's', '-' // hi
        \\   };
        \\    return []u16{'m', 's', 'y', 's',
        \\      '-'};
        \\    return []u16{'m', 's', 'y', 's', '-'};
        \\}
    ,
        \\comptime {
        \\    return []u16{
        \\        'm', 's', 'y', 's', '-', // hi
        \\    };
        \\    return []u16{
        \\        'm', 's', 'y', 's',
        \\        '-',
        \\    };
        \\    return []u16{ 'm', 's', 'y', 's', '-' };
        \\}
        \\
    );
}

test "zig fmt: first thing in file is line comment" {
    try testCanonical(
        \\// Introspection and determination of system libraries needed by zig.
        \\
        \\// Introspection and determination of system libraries needed by zig.
        \\
        \\const std = @import("std");
        \\
    );
}

test "zig fmt: line comment after doc comment" {
    try testCanonical(
        \\/// doc comment
        \\// line comment
        \\fn foo() void {}
        \\
    );
}

test "zig fmt: float literal with exponent" {
    try testCanonical(
        \\test "bit field alignment" {
        \\    assert(@typeOf(&blah.b) == *align(1:3:6) const u3);
        \\}
        \\
    );
}

test "zig fmt: float literal with exponent" {
    try testCanonical(
        \\test "aoeu" {
        \\    switch (state) {
        \\        TermState.Start => switch (c) {
        \\            '\x1b' => state = TermState.Escape,
        \\            else => try out.writeByte(c),
        \\        },
        \\    }
        \\}
        \\
    );
}
test "zig fmt: float literal with exponent" {
    try testCanonical(
        \\pub const f64_true_min = 4.94065645841246544177e-324;
        \\const threshold = 0x1.a827999fcef32p+1022;
        \\
    );
}

test "zig fmt: if-else end of comptime" {
    try testCanonical(
        \\comptime {
        \\    if (a) {
        \\        b();
        \\    } else {
        \\        b();
        \\    }
        \\}
        \\
    );
}

test "zig fmt: nested blocks" {
    try testCanonical(
        \\comptime {
        \\    {
        \\        {
        \\            {
        \\                a();
        \\            }
        \\        }
        \\    }
        \\}
        \\
    );
}

test "zig fmt: block with same line comment after end brace" {
    try testCanonical(
        \\comptime {
        \\    {
        \\        b();
        \\    } // comment
        \\}
        \\
    );
}

test "zig fmt: statements with comment between" {
    try testCanonical(
        \\comptime {
        \\    a = b;
        \\    // comment
        \\    a = b;
        \\}
        \\
    );
}

test "zig fmt: statements with empty line between" {
    try testCanonical(
        \\comptime {
        \\    a = b;
        \\
        \\    a = b;
        \\}
        \\
    );
}

test "zig fmt: ptr deref operator and unwrap optional operator" {
    try testCanonical(
        \\const a = b.*;
        \\const a = b.?;
        \\
    );
}

test "zig fmt: comment after if before another if" {
    try testCanonical(
        \\test "aoeu" {
        \\    // comment
        \\    if (x) {
        \\        bar();
        \\    }
        \\}
        \\
        \\test "aoeu" {
        \\    if (x) {
        \\        foo();
        \\    }
        \\    // comment
        \\    if (x) {
        \\        bar();
        \\    }
        \\}
        \\
    );
}

test "zig fmt: line comment between if block and else keyword" {
    try testCanonical(
        \\test "aoeu" {
        \\    // cexp(finite|nan +- i inf|nan) = nan + i nan
        \\    if ((hx & 0x7fffffff) != 0x7f800000) {
        \\        return Complex(f32).new(y - y, y - y);
        \\    }
        \\    // cexp(-inf +- i inf|nan) = 0 + i0
        \\    else if (hx & 0x80000000 != 0) {
        \\        return Complex(f32).new(0, 0);
        \\    }
        \\    // cexp(+inf +- i inf|nan) = inf + i nan
        \\    // another comment
        \\    else {
        \\        return Complex(f32).new(x, y - y);
        \\    }
        \\}
        \\
    );
}

test "zig fmt: same line comments in expression" {
    try testCanonical(
        \\test "aoeu" {
        \\    const x = ( // a
        \\        0 // b
        \\    ); // c
        \\}
        \\
    );
}

test "zig fmt: add comma on last switch prong" {
    try testTransform(
        \\test "aoeu" {
        \\switch (self.init_arg_expr) {
        \\    InitArg.Type => |t| { },
        \\    InitArg.None,
        \\    InitArg.Enum => { }
        \\}
        \\ switch (self.init_arg_expr) {
        \\     InitArg.Type => |t| { },
        \\     InitArg.None,
        \\     InitArg.Enum => { }//line comment
        \\ }
        \\}
    ,
        \\test "aoeu" {
        \\    switch (self.init_arg_expr) {
        \\        InitArg.Type => |t| {},
        \\        InitArg.None, InitArg.Enum => {},
        \\    }
        \\    switch (self.init_arg_expr) {
        \\        InitArg.Type => |t| {},
        \\        InitArg.None, InitArg.Enum => {}, //line comment
        \\    }
        \\}
        \\
    );
}

test "zig fmt: same-line comment after a statement" {
    try testCanonical(
        \\test "" {
        \\    a = b;
        \\    debug.assert(H.digest_size <= H.block_size); // HMAC makes this assumption
        \\    a = b;
        \\}
        \\
    );
}

test "zig fmt: same-line comment after var decl in struct" {
    try testCanonical(
        \\pub const vfs_cap_data = extern struct {
        \\    const Data = struct {}; // when on disk.
        \\};
        \\
    );
}

test "zig fmt: same-line comment after field decl" {
    try testCanonical(
        \\pub const dirent = extern struct {
        \\    d_name: u8,
        \\    d_name: u8, // comment 1
        \\    d_name: u8,
        \\    d_name: u8, // comment 2
        \\    d_name: u8,
        \\};
        \\
    );
}

test "zig fmt: same-line comment after switch prong" {
    try testCanonical(
        \\test "" {
        \\    switch (err) {
        \\        error.PathAlreadyExists => {}, // comment 2
        \\        else => return err, // comment 1
        \\    }
        \\}
        \\
    );
}

test "zig fmt: same-line comment after non-block if expression" {
    try testCanonical(
        \\comptime {
        \\    if (sr > n_uword_bits - 1) // d > r
        \\        return 0;
        \\}
        \\
    );
}

test "zig fmt: same-line comment on comptime expression" {
    try testCanonical(
        \\test "" {
        \\    comptime assert(@typeId(T) == builtin.TypeId.Int); // must pass an integer to absInt
        \\}
        \\
    );
}

test "zig fmt: switch with empty body" {
    try testCanonical(
        \\test "" {
        \\    foo() catch |err| switch (err) {};
        \\}
        \\
    );
}

test "zig fmt: line comments in struct initializer" {
    try testCanonical(
        \\fn foo() void {
        \\    return Self{
        \\        .a = b,
        \\
        \\        // Initialize these two fields to buffer_size so that
        \\        // in `readFn` we treat the state as being able to read
        \\        .start_index = buffer_size,
        \\        .end_index = buffer_size,
        \\
        \\        // middle
        \\
        \\        .a = b,
        \\
        \\        // end
        \\    };
        \\}
        \\
    );
}

test "zig fmt: first line comment in struct initializer" {
    try testCanonical(
        \\pub async fn acquire(self: *Self) HeldLock {
        \\    return HeldLock{
        \\        // TODO guaranteed allocation elision
        \\        .held = await (async self.lock.acquire() catch unreachable),
        \\        .value = &self.private_data,
        \\    };
        \\}
        \\
    );
}

test "zig fmt: doc comments before struct field" {
    try testCanonical(
        \\pub const Allocator = struct {
        \\    /// Allocate byte_count bytes and return them in a slice, with the
        \\    /// slice's pointer aligned at least to alignment bytes.
        \\    allocFn: fn () void,
        \\};
        \\
    );
}

test "zig fmt: error set declaration" {
    try testCanonical(
        \\const E = error{
        \\    A,
        \\    B,
        \\
        \\    C,
        \\};
        \\
        \\const Error = error{
        \\    /// no more memory
        \\    OutOfMemory,
        \\};
        \\
        \\const Error = error{
        \\    /// no more memory
        \\    OutOfMemory,
        \\
        \\    /// another
        \\    Another,
        \\
        \\    // end
        \\};
        \\
        \\const Error = error{OutOfMemory};
        \\const Error = error{};
        \\
    );
}

test "zig fmt: union(enum(u32)) with assigned enum values" {
    try testCanonical(
        \\const MultipleChoice = union(enum(u32)) {
        \\    A = 20,
        \\    B = 40,
        \\    C = 60,
        \\    D = 1000,
        \\};
        \\
    );
}

test "zig fmt: resume from suspend block" {
    try testCanonical(
        \\fn foo() void {
        \\    suspend {
        \\        resume @handle();
        \\    }
        \\}
        \\
    );
}

test "zig fmt: comments before error set decl" {
    try testCanonical(
        \\const UnexpectedError = error{
        \\    /// The Operating System returned an undocumented error code.
        \\    Unexpected,
        \\    // another
        \\    Another,
        \\
        \\    // in between
        \\
        \\    // at end
        \\};
        \\
    );
}

test "zig fmt: comments before switch prong" {
    try testCanonical(
        \\test "" {
        \\    switch (err) {
        \\        error.PathAlreadyExists => continue,
        \\
        \\        // comment 1
        \\
        \\        // comment 2
        \\        else => return err,
        \\        // at end
        \\    }
        \\}
        \\
    );
}

test "zig fmt: comments before var decl in struct" {
    try testCanonical(
        \\pub const vfs_cap_data = extern struct {
        \\    // All of these are mandated as little endian
        \\    // when on disk.
        \\    const Data = struct {
        \\        permitted: u32,
        \\        inheritable: u32,
        \\    };
        \\
        \\    // in between
        \\
        \\    /// All of these are mandated as little endian
        \\    /// when on disk.
        \\    const Data = struct {
        \\        permitted: u32,
        \\        inheritable: u32,
        \\    };
        \\
        \\    // at end
        \\};
        \\
    );
}

test "zig fmt: array literal with 1 item on 1 line" {
    try testCanonical(
        \\var s = []const u64{0} ** 25;
        \\
    );
}

test "zig fmt: comments before global variables" {
    try testCanonical(
        \\/// Foo copies keys and values before they go into the map, and
        \\/// frees them when they get removed.
        \\pub const Foo = struct {};
        \\
    );
}

test "zig fmt: comments in statements" {
    try testCanonical(
        \\test "std" {
        \\    // statement comment
        \\    _ = @import("foo/bar.zig");
        \\
        \\    // middle
        \\    // middle2
        \\
        \\    // end
        \\}
        \\
    );
}

test "zig fmt: comments before test decl" {
    try testCanonical(
        \\/// top level doc comment
        \\test "hi" {}
        \\
        \\// top level normal comment
        \\test "hi" {}
        \\
        \\// middle
        \\
        \\// end
        \\
    );
}

test "zig fmt: preserve spacing" {
    try testCanonical(
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    var stdout_file = try std.io.getStdOut;
        \\    var stdout_file = try std.io.getStdOut;
        \\
        \\    var stdout_file = try std.io.getStdOut;
        \\    var stdout_file = try std.io.getStdOut;
        \\}
        \\
    );
}

test "zig fmt: return types" {
    try testCanonical(
        \\pub fn main() !void {}
        \\pub fn main() var {}
        \\pub fn main() i32 {}
        \\
    );
}

test "zig fmt: imports" {
    try testCanonical(
        \\const std = @import("std");
        \\const std = @import();
        \\
    );
}

test "zig fmt: global declarations" {
    try testCanonical(
        \\const a = b;
        \\pub const a = b;
        \\var a = b;
        \\pub var a = b;
        \\const a: i32 = b;
        \\pub const a: i32 = b;
        \\var a: i32 = b;
        \\pub var a: i32 = b;
        \\extern const a: i32 = b;
        \\pub extern const a: i32 = b;
        \\extern var a: i32 = b;
        \\pub extern var a: i32 = b;
        \\extern "a" const a: i32 = b;
        \\pub extern "a" const a: i32 = b;
        \\extern "a" var a: i32 = b;
        \\pub extern "a" var a: i32 = b;
        \\
    );
}

test "zig fmt: extern declaration" {
    try testCanonical(
        \\extern var foo: c_int;
        \\
    );
}

test "zig fmt: alignment" {
    try testCanonical(
        \\var foo: c_int align(1);
        \\
    );
}

test "zig fmt: C main" {
    try testCanonical(
        \\fn main(argc: c_int, argv: **u8) c_int {
        \\    const a = b;
        \\}
        \\
    );
}

test "zig fmt: return" {
    try testCanonical(
        \\fn foo(argc: c_int, argv: **u8) c_int {
        \\    return 0;
        \\}
        \\
        \\fn bar() void {
        \\    return;
        \\}
        \\
    );
}

test "zig fmt: pointer attributes" {
    try testCanonical(
        \\extern fn f1(s: *align(*u8) u8) c_int;
        \\extern fn f2(s: **align(1) *const *volatile u8) c_int;
        \\extern fn f3(s: *align(1) const *align(1) volatile *const volatile u8) c_int;
        \\extern fn f4(s: *align(1) const volatile u8) c_int;
        \\
    );
}

test "zig fmt: slice attributes" {
    try testCanonical(
        \\extern fn f1(s: *align(*u8) u8) c_int;
        \\extern fn f2(s: **align(1) *const *volatile u8) c_int;
        \\extern fn f3(s: *align(1) const *align(1) volatile *const volatile u8) c_int;
        \\extern fn f4(s: *align(1) const volatile u8) c_int;
        \\
    );
}

test "zig fmt: test declaration" {
    try testCanonical(
        \\test "test name" {
        \\    const a = 1;
        \\    var b = 1;
        \\}
        \\
    );
}

test "zig fmt: infix operators" {
    try testCanonical(
        \\test "infix operators" {
        \\    var i = undefined;
        \\    i = 2;
        \\    i *= 2;
        \\    i |= 2;
        \\    i ^= 2;
        \\    i <<= 2;
        \\    i >>= 2;
        \\    i &= 2;
        \\    i *= 2;
        \\    i *%= 2;
        \\    i -= 2;
        \\    i -%= 2;
        \\    i += 2;
        \\    i +%= 2;
        \\    i /= 2;
        \\    i %= 2;
        \\    _ = i == i;
        \\    _ = i != i;
        \\    _ = i != i;
        \\    _ = i.i;
        \\    _ = i || i;
        \\    _ = i!i;
        \\    _ = i ** i;
        \\    _ = i ++ i;
        \\    _ = i orelse i;
        \\    _ = i % i;
        \\    _ = i / i;
        \\    _ = i *% i;
        \\    _ = i * i;
        \\    _ = i -% i;
        \\    _ = i - i;
        \\    _ = i +% i;
        \\    _ = i + i;
        \\    _ = i << i;
        \\    _ = i >> i;
        \\    _ = i & i;
        \\    _ = i ^ i;
        \\    _ = i | i;
        \\    _ = i >= i;
        \\    _ = i <= i;
        \\    _ = i > i;
        \\    _ = i < i;
        \\    _ = i and i;
        \\    _ = i or i;
        \\}
        \\
    );
}

test "zig fmt: precedence" {
    try testCanonical(
        \\test "precedence" {
        \\    a!b();
        \\    (a!b)();
        \\    !a!b;
        \\    !(a!b);
        \\    !a{};
        \\    !(a{});
        \\    a + b{};
        \\    (a + b){};
        \\    a << b + c;
        \\    (a << b) + c;
        \\    a & b << c;
        \\    (a & b) << c;
        \\    a ^ b & c;
        \\    (a ^ b) & c;
        \\    a | b ^ c;
        \\    (a | b) ^ c;
        \\    a == b | c;
        \\    (a == b) | c;
        \\    a and b == c;
        \\    (a and b) == c;
        \\    a or b and c;
        \\    (a or b) and c;
        \\    (a or b) and c;
        \\}
        \\
    );
}

test "zig fmt: prefix operators" {
    try testCanonical(
        \\test "prefix operators" {
        \\    try return --%~!*&0;
        \\}
        \\
    );
}

test "zig fmt: call expression" {
    try testCanonical(
        \\test "test calls" {
        \\    a();
        \\    a(1);
        \\    a(1, 2);
        \\    a(1, 2) + a(1, 2);
        \\}
        \\
    );
}

test "zig fmt: var args" {
    try testCanonical(
        \\fn print(args: ...) void {}
        \\
    );
}

test "zig fmt: var type" {
    try testCanonical(
        \\fn print(args: var) var {}
        \\const Var = var;
        \\const i: var = 0;
        \\
    );
}

test "zig fmt: functions" {
    try testCanonical(
        \\extern fn puts(s: *const u8) c_int;
        \\extern "c" fn puts(s: *const u8) c_int;
        \\export fn puts(s: *const u8) c_int;
        \\inline fn puts(s: *const u8) c_int;
        \\pub extern fn puts(s: *const u8) c_int;
        \\pub extern "c" fn puts(s: *const u8) c_int;
        \\pub export fn puts(s: *const u8) c_int;
        \\pub inline fn puts(s: *const u8) c_int;
        \\pub extern fn puts(s: *const u8) align(2 + 2) c_int;
        \\pub extern "c" fn puts(s: *const u8) align(2 + 2) c_int;
        \\pub export fn puts(s: *const u8) align(2 + 2) c_int;
        \\pub inline fn puts(s: *const u8) align(2 + 2) c_int;
        \\
    );
}

test "zig fmt: multiline string" {
    try testCanonical(
        \\test "" {
        \\    const s1 =
        \\        \\one
        \\        \\two)
        \\        \\three
        \\    ;
        \\    const s2 =
        \\        c\\one
        \\        c\\two)
        \\        c\\three
        \\    ;
        \\    const s3 = // hi
        \\        \\one
        \\        \\two)
        \\        \\three
        \\    ;
        \\}
        \\
    );
}

test "zig fmt: values" {
    try testCanonical(
        \\test "values" {
        \\    1;
        \\    1.0;
        \\    "string";
        \\    c"cstring";
        \\    'c';
        \\    true;
        \\    false;
        \\    null;
        \\    undefined;
        \\    anyerror;
        \\    this;
        \\    unreachable;
        \\}
        \\
    );
}

test "zig fmt: indexing" {
    try testCanonical(
        \\test "test index" {
        \\    a[0];
        \\    a[0 + 5];
        \\    a[0..];
        \\    a[0..5];
        \\    a[a[0]];
        \\    a[a[0..]];
        \\    a[a[0..5]];
        \\    a[a[0]..];
        \\    a[a[0..5]..];
        \\    a[a[0]..a[0]];
        \\    a[a[0..5]..a[0]];
        \\    a[a[0..5]..a[0..5]];
        \\}
        \\
    );
}

test "zig fmt: struct declaration" {
    try testCanonical(
        \\const S = struct {
        \\    const Self = @This();
        \\    f1: u8,
        \\    pub f3: u8,
        \\
        \\    fn method(self: *Self) Self {
        \\        return self.*;
        \\    }
        \\
        \\    f2: u8,
        \\};
        \\
        \\const Ps = packed struct {
        \\    a: u8,
        \\    pub b: u8,
        \\
        \\    c: u8,
        \\};
        \\
        \\const Es = extern struct {
        \\    a: u8,
        \\    pub b: u8,
        \\
        \\    c: u8,
        \\};
        \\
    );
}

test "zig fmt: enum declaration" {
    try testCanonical(
        \\const E = enum {
        \\    Ok,
        \\    SomethingElse = 0,
        \\};
        \\
        \\const E2 = enum(u8) {
        \\    Ok,
        \\    SomethingElse = 255,
        \\    SomethingThird,
        \\};
        \\
        \\const Ee = extern enum {
        \\    Ok,
        \\    SomethingElse,
        \\    SomethingThird,
        \\};
        \\
        \\const Ep = packed enum {
        \\    Ok,
        \\    SomethingElse,
        \\    SomethingThird,
        \\};
        \\
    );
}

test "zig fmt: union declaration" {
    try testCanonical(
        \\const U = union {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool,
        \\};
        \\
        \\const Ue = union(enum) {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool,
        \\};
        \\
        \\const E = enum {
        \\    Int,
        \\    Float,
        \\    None,
        \\    Bool,
        \\};
        \\
        \\const Ue2 = union(E) {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool,
        \\};
        \\
        \\const Eu = extern union {
        \\    Int: u8,
        \\    Float: f32,
        \\    None,
        \\    Bool: bool,
        \\};
        \\
    );
}

test "zig fmt: arrays" {
    try testCanonical(
        \\test "test array" {
        \\    const a: [2]u8 = [2]u8{
        \\        1,
        \\        2,
        \\    };
        \\    const a: [2]u8 = []u8{
        \\        1,
        \\        2,
        \\    };
        \\    const a: [0]u8 = []u8{};
        \\}
        \\
    );
}

test "zig fmt: container initializers" {
    try testCanonical(
        \\const a0 = []u8{};
        \\const a1 = []u8{1};
        \\const a2 = []u8{
        \\    1,
        \\    2,
        \\    3,
        \\    4,
        \\};
        \\const s0 = S{};
        \\const s1 = S{ .a = 1 };
        \\const s2 = S{
        \\    .a = 1,
        \\    .b = 2,
        \\};
        \\
    );
}

test "zig fmt: catch" {
    try testCanonical(
        \\test "catch" {
        \\    const a: anyerror!u8 = 0;
        \\    _ = a catch return;
        \\    _ = a catch |err| return;
        \\}
        \\
    );
}

test "zig fmt: blocks" {
    try testCanonical(
        \\test "blocks" {
        \\    {
        \\        const a = 0;
        \\        const b = 0;
        \\    }
        \\
        \\    blk: {
        \\        const a = 0;
        \\        const b = 0;
        \\    }
        \\
        \\    const r = blk: {
        \\        const a = 0;
        \\        const b = 0;
        \\    };
        \\}
        \\
    );
}

test "zig fmt: switch" {
    try testCanonical(
        \\test "switch" {
        \\    switch (0) {
        \\        0 => {},
        \\        1 => unreachable,
        \\        2, 3 => {},
        \\        4...7 => {},
        \\        1 + 4 * 3 + 22 => {},
        \\        else => {
        \\            const a = 1;
        \\            const b = a;
        \\        },
        \\    }
        \\
        \\    const res = switch (0) {
        \\        0 => 0,
        \\        1 => 2,
        \\        1 => a = 4,
        \\        else => 4,
        \\    };
        \\
        \\    const Union = union(enum) {
        \\        Int: i64,
        \\        Float: f64,
        \\    };
        \\
        \\    switch (u) {
        \\        Union.Int => |int| {},
        \\        Union.Float => |*float| unreachable,
        \\    }
        \\}
        \\
    );
}

test "zig fmt: while" {
    try testCanonical(
        \\test "while" {
        \\    while (10 < 1) unreachable;
        \\
        \\    while (10 < 1) unreachable else unreachable;
        \\
        \\    while (10 < 1) {
        \\        unreachable;
        \\    }
        \\
        \\    while (10 < 1)
        \\        unreachable;
        \\
        \\    var i: usize = 0;
        \\    while (i < 10) : (i += 1) {
        \\        continue;
        \\    }
        \\
        \\    i = 0;
        \\    while (i < 10) : (i += 1)
        \\        continue;
        \\
        \\    i = 0;
        \\    var j: usize = 0;
        \\    while (i < 10) : ({
        \\        i += 1;
        \\        j += 1;
        \\    }) {
        \\        continue;
        \\    }
        \\
        \\    var a: ?u8 = 2;
        \\    while (a) |v| : (a = null) {
        \\        continue;
        \\    }
        \\
        \\    while (a) |v| : (a = null)
        \\        unreachable;
        \\
        \\    label: while (10 < 0) {
        \\        unreachable;
        \\    }
        \\
        \\    const res = while (0 < 10) {
        \\        break 7;
        \\    } else {
        \\        unreachable;
        \\    };
        \\
        \\    const res = while (0 < 10)
        \\        break 7
        \\    else
        \\        unreachable;
        \\
        \\    var a: anyerror!u8 = 0;
        \\    while (a) |v| {
        \\        a = error.Err;
        \\    } else |err| {
        \\        i = 1;
        \\    }
        \\
        \\    comptime var k: usize = 0;
        \\    inline while (i < 10) : (i += 1)
        \\        j += 2;
        \\}
        \\
    );
}

test "zig fmt: for" {
    try testCanonical(
        \\test "for" {
        \\    for (a) continue;
        \\
        \\    for (a)
        \\        continue;
        \\
        \\    for (a) {
        \\        continue;
        \\    }
        \\
        \\    for (a) |v| {
        \\        continue;
        \\    }
        \\
        \\    for (a) |v| continue;
        \\
        \\    for (a) |v| continue else return;
        \\
        \\    for (a) |v| {
        \\        continue;
        \\    } else return;
        \\
        \\    for (a) |v| continue else {
        \\        return;
        \\    }
        \\
        \\    for (a) |v|
        \\        continue
        \\    else
        \\        return;
        \\
        \\    for (a) |v|
        \\        continue;
        \\
        \\    for (a) |*v|
        \\        continue;
        \\
        \\    for (a) |v, i| {
        \\        continue;
        \\    }
        \\
        \\    for (a) |v, i|
        \\        continue;
        \\
        \\    for (a) |b| switch (b) {
        \\        c => {},
        \\        d => {},
        \\    };
        \\
        \\    for (a) |b|
        \\        switch (b) {
        \\            c => {},
        \\            d => {},
        \\        };
        \\
        \\    const res = for (a) |v, i| {
        \\        break v;
        \\    } else {
        \\        unreachable;
        \\    };
        \\
        \\    var num: usize = 0;
        \\    inline for (a) |v, i| {
        \\        num += v;
        \\        num += i;
        \\    }
        \\}
        \\
    );

    try testTransform(
        \\test "fix for" {
        \\    for (a) |x|
        \\        f(x) else continue;
        \\}
        \\
    ,
        \\test "fix for" {
        \\    for (a) |x|
        \\        f(x)
        \\    else continue;
        \\}
        \\
    );
}

test "zig fmt: if" {
    try testCanonical(
        \\test "if" {
        \\    if (10 < 0) {
        \\        unreachable;
        \\    }
        \\
        \\    if (10 < 0) unreachable;
        \\
        \\    if (10 < 0) {
        \\        unreachable;
        \\    } else {
        \\        const a = 20;
        \\    }
        \\
        \\    if (10 < 0) {
        \\        unreachable;
        \\    } else if (5 < 0) {
        \\        unreachable;
        \\    } else {
        \\        const a = 20;
        \\    }
        \\
        \\    const is_world_broken = if (10 < 0) true else false;
        \\    const some_number = 1 + if (10 < 0) 2 else 3;
        \\
        \\    const a: ?u8 = 10;
        \\    const b: ?u8 = null;
        \\    if (a) |v| {
        \\        const some = v;
        \\    } else if (b) |*v| {
        \\        unreachable;
        \\    } else {
        \\        const some = 10;
        \\    }
        \\
        \\    const non_null_a = if (a) |v| v else 0;
        \\
        \\    const a_err: anyerror!u8 = 0;
        \\    if (a_err) |v| {
        \\        const p = v;
        \\    } else |err| {
        \\        unreachable;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: defer" {
    try testCanonical(
        \\test "defer" {
        \\    var i: usize = 0;
        \\    defer i = 1;
        \\    defer {
        \\        i += 2;
        \\        i *= i;
        \\    }
        \\
        \\    errdefer i += 3;
        \\    errdefer {
        \\        i += 2;
        \\        i /= i;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: comptime" {
    try testCanonical(
        \\fn a() u8 {
        \\    return 5;
        \\}
        \\
        \\fn b(comptime i: u8) u8 {
        \\    return i;
        \\}
        \\
        \\const av = comptime a();
        \\const av2 = comptime blk: {
        \\    var res = a();
        \\    res *= b(2);
        \\    break :blk res;
        \\};
        \\
        \\comptime {
        \\    _ = a();
        \\}
        \\
        \\test "comptime" {
        \\    const av3 = comptime a();
        \\    const av4 = comptime blk: {
        \\        var res = a();
        \\        res *= a();
        \\        break :blk res;
        \\    };
        \\
        \\    comptime var i = 0;
        \\    comptime {
        \\        i = a();
        \\        i += b(i);
        \\    }
        \\}
        \\
    );
}

test "zig fmt: fn type" {
    try testCanonical(
        \\fn a(i: u8) u8 {
        \\    return i + 1;
        \\}
        \\
        \\const a: fn (u8) u8 = undefined;
        \\const b: extern fn (u8) u8 = undefined;
        \\const c: nakedcc fn (u8) u8 = undefined;
        \\const ap: fn (u8) u8 = a;
        \\
    );
}

test "zig fmt: inline asm" {
    try testCanonical(
        \\pub fn syscall1(number: usize, arg1: usize) usize {
        \\    return asm volatile ("syscall"
        \\        : [ret] "={rax}" (-> usize)
        \\        : [number] "{rax}" (number),
        \\          [arg1] "{rdi}" (arg1)
        \\        : "rcx", "r11"
        \\    );
        \\}
        \\
    );
}

test "zig fmt: coroutines" {
    try testCanonical(
        \\async fn simpleAsyncFn() void {
        \\    const a = async a.b();
        \\    x += 1;
        \\    suspend;
        \\    x += 1;
        \\    suspend;
        \\    const p: promise->void = async simpleAsyncFn() catch unreachable;
        \\    await p;
        \\}
        \\
        \\test "coroutine suspend, resume, cancel" {
        \\    const p: promise = try async<std.debug.global_allocator> testAsyncSeq();
        \\    resume p;
        \\    cancel p;
        \\}
        \\
    );
}

test "zig fmt: Block after if" {
    try testCanonical(
        \\test "Block after if" {
        \\    if (true) {
        \\        const a = 0;
        \\    }
        \\
        \\    {
        \\        const a = 0;
        \\    }
        \\}
        \\
    );
}

test "zig fmt: use" {
    try testCanonical(
        \\use @import("std");
        \\pub use @import("std");
        \\
    );
}

test "zig fmt: string identifier" {
    try testCanonical(
        \\const @"a b" = @"c d".@"e f";
        \\fn @"g h"() void {}
        \\
    );
}

test "zig fmt: error return" {
    try testCanonical(
        \\fn err() anyerror {
        \\    call();
        \\    return error.InvalidArgs;
        \\}
        \\
    );
}

const std = @import("std");
const mem = std.mem;
const warn = std.debug.warn;
const io = std.io;
const maxInt = std.math.maxInt;

var fixed_buffer_mem: [100 * 1024]u8 = undefined;

fn testParse(source: []const u8, allocator: *mem.Allocator, anything_changed: *bool) ![]u8 {
    var stderr_file = try io.getStdErr();
    var stderr = &stderr_file.outStream().stream;

    var tree = try std.zig.parse2(allocator, source);
    defer tree.deinit();

    var error_it = tree.errors.iterator(0);
    while (error_it.next()) |parse_error| {
        const token = tree.tokens.at(parse_error.loc());
        const loc = tree.tokenLocation(0, parse_error.loc());
        try stderr.print("(memory buffer):{}:{}: error: ", loc.line + 1, loc.column + 1);
        try tree.renderError(parse_error, stderr);
        try stderr.print("\n{}\n", source[loc.line_start..loc.line_end]);
        {
            var i: usize = 0;
            while (i < loc.column) : (i += 1) {
                try stderr.write(" ");
            }
        }
        {
            const caret_count = token.end - token.start;
            var i: usize = 0;
            while (i < caret_count) : (i += 1) {
                try stderr.write("~");
            }
        }
        try stderr.write("\n");
    }
    if (tree.errors.len != 0) {
        return error.ParseError;
    }

    var buffer = try std.Buffer.initSize(allocator, 0);
    errdefer buffer.deinit();

    var buffer_out_stream = io.BufferOutStream.init(&buffer);
    anything_changed.* = try std.zig.render(allocator, &buffer_out_stream.stream, &tree);
    return buffer.toOwnedSlice();
}

fn testTransform(source: []const u8, expected_source: []const u8) !void {
    const needed_alloc_count = x: {
        // Try it once with unlimited memory, make sure it works
        var fixed_allocator = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
        var failing_allocator = std.debug.FailingAllocator.init(&fixed_allocator.allocator, maxInt(usize));
        var anything_changed: bool = undefined;
        const result_source = try testParse(source, &failing_allocator.allocator, &anything_changed);
        if (!mem.eql(u8, result_source, expected_source)) {
            warn("\n====== expected this output: =========\n");
            warn("{}", expected_source);
            warn("\n======== instead found this: =========\n");
            warn("{}", result_source);
            warn("\n======================================\n");
            return error.TestFailed;
        }
        const changes_expected = source.ptr != expected_source.ptr;
        if (anything_changed != changes_expected) {
            warn("std.zig.render returned {} instead of {}\n", anything_changed, changes_expected);
            return error.TestFailed;
        }
        std.testing.expect(anything_changed == changes_expected);
        failing_allocator.allocator.free(result_source);
        break :x failing_allocator.index;
    };

    var fail_index: usize = 0;
    while (fail_index < needed_alloc_count) : (fail_index += 1) {
        var fixed_allocator = std.heap.FixedBufferAllocator.init(fixed_buffer_mem[0..]);
        var failing_allocator = std.debug.FailingAllocator.init(&fixed_allocator.allocator, fail_index);
        var anything_changed: bool = undefined;
        if (testParse(source, &failing_allocator.allocator, &anything_changed)) |_| {
            return error.NondeterministicMemoryUsage;
        } else |err| switch (err) {
            error.OutOfMemory => {
                if (failing_allocator.allocated_bytes != failing_allocator.freed_bytes) {
                    warn(
                        "\nfail_index: {}/{}\nallocated bytes: {}\nfreed bytes: {}\nallocations: {}\ndeallocations: {}\n",
                        fail_index,
                        needed_alloc_count,
                        failing_allocator.allocated_bytes,
                        failing_allocator.freed_bytes,
                        failing_allocator.index,
                        failing_allocator.deallocations,
                    );
                    return error.MemoryLeakDetected;
                }
            },
            error.ParseError => @panic("test failed"),
            else => @panic("test failed"),
        }
    }
}

fn testCanonical(source: []const u8) !void {
    return testTransform(source, source);
}
