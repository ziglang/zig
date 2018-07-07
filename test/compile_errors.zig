const tests = @import("tests.zig");

pub fn addCases(cases: *tests.CompileErrorContext) void {
    cases.add(
        "@popCount - non-integer",
        \\export fn entry(x: f32) u32 {
        \\    return @popCount(x);
        \\}
    ,
        ".tmp_source.zig:2:22: error: expected integer type, found 'f32'",
    );

    cases.add(
        "@popCount - negative comptime_int",
        \\comptime {
        \\    _ = @popCount(-1);
        \\}
    ,
        ".tmp_source.zig:2:9: error: @popCount on negative comptime_int value -1",
    );

    cases.addCase(x: {
        const tc = cases.create(
            "wrong same named struct",
            \\const a = @import("a.zig");
            \\const b = @import("b.zig");
            \\
            \\export fn entry() void {
            \\    var a1: a.Foo = undefined;
            \\    bar(&a1);
            \\}
            \\
            \\fn bar(x: *b.Foo) void {}
        ,
            ".tmp_source.zig:6:10: error: expected type '*Foo', found '*Foo'",
            ".tmp_source.zig:6:10: note: pointer type child 'Foo' cannot cast into pointer type child 'Foo'",
            "a.zig:1:17: note: Foo declared here",
            "b.zig:1:17: note: Foo declared here",
        );

        tc.addSourceFile("a.zig",
            \\pub const Foo = struct {
            \\    x: i32,
            \\};
        );

        tc.addSourceFile("b.zig",
            \\pub const Foo = struct {
            \\    z: f64,
            \\};
        );

        break :x tc;
    });

    cases.add(
        "enum field value references enum",
        \\pub const Foo = extern enum {
        \\    A = Foo.B,
        \\    C = D,
        \\};
        \\export fn entry() void {
        \\    var s: Foo = Foo.E;
        \\}
    ,
        ".tmp_source.zig:1:17: error: 'Foo' depends on itself",
    );

    cases.add(
        "@floatToInt comptime safety",
        \\comptime {
        \\    _ = @floatToInt(i8, f32(-129.1));
        \\}
        \\comptime {
        \\    _ = @floatToInt(u8, f32(-1.1));
        \\}
        \\comptime {
        \\    _ = @floatToInt(u8, f32(256.1));
        \\}
    ,
        ".tmp_source.zig:2:9: error: integer value '-129' cannot be stored in type 'i8'",
        ".tmp_source.zig:5:9: error: integer value '-1' cannot be stored in type 'u8'",
        ".tmp_source.zig:8:9: error: integer value '256' cannot be stored in type 'u8'",
    );

    cases.add(
        "use c_void as return type of fn ptr",
        \\export fn entry() void {
        \\    const a: fn () c_void = undefined;
        \\}
    ,
        ".tmp_source.zig:2:20: error: return type cannot be opaque",
    );

    cases.add(
        "non int passed to @intToFloat",
        \\export fn entry() void {
        \\    const x = @intToFloat(f32, 1.1);
        \\}
    ,
        ".tmp_source.zig:2:32: error: expected int type, found 'comptime_float'",
    );

    cases.add(
        "use implicit casts to assign null to non-nullable pointer",
        \\export fn entry() void {
        \\    var x: i32 = 1234;
        \\    var p: *i32 = &x;
        \\    var pp: *?*i32 = &p;
        \\    pp.* = null;
        \\    var y = p.*;
        \\}
    ,
        ".tmp_source.zig:4:23: error: expected type '*?*i32', found '**i32'",
    );

    cases.add(
        "attempted implicit cast from T to [*]const T",
        \\export fn entry() void {
        \\    const x: [*]const bool = true;
        \\}
    ,
        ".tmp_source.zig:2:30: error: expected type '[*]const bool', found 'bool'",
    );

    cases.add(
        "dereference unknown length pointer",
        \\export fn entry(x: [*]i32) i32 {
        \\    return x.*;
        \\}
    ,
        ".tmp_source.zig:2:13: error: index syntax required for unknown-length pointer type '[*]i32'",
    );

    cases.add(
        "field access of unknown length pointer",
        \\const Foo = extern struct {
        \\    a: i32,
        \\};
        \\
        \\export fn entry(foo: [*]Foo) void {
        \\    foo.a += 1;
        \\}
    ,
        ".tmp_source.zig:6:8: error: type '[*]Foo' does not support field access",
    );

    cases.add(
        "unknown length pointer to opaque",
        \\export const T = [*]@OpaqueType();
    ,
        ".tmp_source.zig:1:18: error: unknown-length pointer to opaque",
    );

    cases.add(
        "error when evaluating return type",
        \\const Foo = struct {
        \\    map: i32(i32),
        \\
        \\    fn init() Foo {
        \\        return undefined;
        \\    }
        \\};
        \\export fn entry() void {
        \\    var rule_set = try Foo.init();
        \\}
    ,
        ".tmp_source.zig:2:13: error: expected type 'i32', found 'type'",
    );

    cases.add(
        "slicing single-item pointer",
        \\export fn entry(ptr: *i32) void {
        \\    const slice = ptr[0..2];
        \\}
    ,
        ".tmp_source.zig:2:22: error: slice of single-item pointer",
    );

    cases.add(
        "indexing single-item pointer",
        \\export fn entry(ptr: *i32) i32 {
        \\    return ptr[1];
        \\}
    ,
        ".tmp_source.zig:2:15: error: index of single-item pointer",
    );

    cases.add(
        "nested error set mismatch",
        \\const NextError = error{NextError};
        \\const OtherError = error{OutOfMemory};
        \\
        \\export fn entry() void {
        \\    const a: ?NextError!i32 = foo();
        \\}
        \\
        \\fn foo() ?OtherError!i32 {
        \\    return null;
        \\}
    ,
        ".tmp_source.zig:5:34: error: expected type '?NextError!i32', found '?OtherError!i32'",
        ".tmp_source.zig:5:34: note: optional type child 'OtherError!i32' cannot cast into optional type child 'NextError!i32'",
        ".tmp_source.zig:5:34: note: error set 'OtherError' cannot cast into error set 'NextError'",
        ".tmp_source.zig:2:26: note: 'error.OutOfMemory' not a member of destination error set",
    );

    cases.add(
        "invalid deref on switch target",
        \\comptime {
        \\    var tile = Tile.Empty;
        \\    switch (tile.*) {
        \\        Tile.Empty => {},
        \\        Tile.Filled => {},
        \\    }
        \\}
        \\const Tile = enum {
        \\    Empty,
        \\    Filled,
        \\};
    ,
        ".tmp_source.zig:3:17: error: invalid deref on switch target",
    );

    cases.add(
        "invalid field access in comptime",
        \\comptime { var x = doesnt_exist.whatever; }
    ,
        ".tmp_source.zig:1:20: error: use of undeclared identifier 'doesnt_exist'",
    );

    cases.add(
        "suspend inside suspend block",
        \\const std = @import("std",);
        \\
        \\export fn entry() void {
        \\    var buf: [500]u8 = undefined;
        \\    var a = &std.heap.FixedBufferAllocator.init(buf[0..]).allocator;
        \\    const p = (async<a> foo()) catch unreachable;
        \\    cancel p;
        \\}
        \\
        \\async fn foo() void {
        \\    suspend |p| {
        \\        suspend |p1| {
        \\        }
        \\    }
        \\}
    ,
        ".tmp_source.zig:12:9: error: cannot suspend inside suspend block",
        ".tmp_source.zig:11:5: note: other suspend block here",
    );

    cases.add(
        "assign inline fn to non-comptime var",
        \\export fn entry() void {
        \\    var a = b;
        \\}
        \\inline fn b() void { }
    ,
        ".tmp_source.zig:2:5: error: functions marked inline must be stored in const or comptime var",
        ".tmp_source.zig:4:8: note: declared here",
    );

    cases.add(
        "wrong type passed to @panic",
        \\export fn entry() void {
        \\    var e = error.Foo;
        \\    @panic(e);
        \\}
    ,
        ".tmp_source.zig:3:12: error: expected type '[]const u8', found 'error{Foo}'",
    );

    cases.add(
        "@tagName used on union with no associated enum tag",
        \\const FloatInt = extern union {
        \\    Float: f32,
        \\    Int: i32,
        \\};
        \\export fn entry() void {
        \\    var fi = FloatInt{.Float = 123.45};
        \\    var tagName = @tagName(fi);
        \\}
    ,
        ".tmp_source.zig:7:19: error: union has no associated enum",
        ".tmp_source.zig:1:18: note: declared here",
    );

    cases.add(
        "returning error from void async function",
        \\const std = @import("std",);
        \\export fn entry() void {
        \\    const p = async<std.debug.global_allocator> amain() catch unreachable;
        \\}
        \\async fn amain() void {
        \\    return error.ShouldBeCompileError;
        \\}
    ,
        ".tmp_source.zig:6:17: error: expected type 'void', found 'error{ShouldBeCompileError}'",
    );

    cases.add(
        "var not allowed in structs",
        \\export fn entry() void {
        \\   var s = (struct{v: var}){.v=i32(10)};
        \\}
    ,
        ".tmp_source.zig:2:23: error: invalid token: 'var'",
    );

    cases.add(
        "@ptrCast discards const qualifier",
        \\export fn entry() void {
        \\    const x: i32 = 1234;
        \\    const y = @ptrCast(*i32, &x);
        \\}
    ,
        ".tmp_source.zig:3:15: error: cast discards const qualifier",
    );

    cases.add(
        "comptime slice of undefined pointer non-zero len",
        \\export fn entry() void {
        \\    const slice = ([*]i32)(undefined)[0..1];
        \\}
    ,
        ".tmp_source.zig:2:38: error: non-zero length slice of undefined pointer",
    );

    cases.add(
        "type checking function pointers",
        \\fn a(b: fn (*const u8) void) void {
        \\    b('a');
        \\}
        \\fn c(d: u8) void {
        \\    @import("std").debug.warn("{c}\n", d);
        \\}
        \\export fn entry() void {
        \\    a(c);
        \\}
    ,
        ".tmp_source.zig:8:7: error: expected type 'fn(*const u8) void', found 'fn(u8) void'",
    );

    cases.add(
        "no else prong on switch on global error set",
        \\export fn entry() void {
        \\    foo(error.A);
        \\}
        \\fn foo(a: error) void {
        \\    switch (a) {
        \\        error.A => {},
        \\    }
        \\}
    ,
        ".tmp_source.zig:5:5: error: else prong required when switching on type 'error'",
    );

    cases.add(
        "inferred error set with no returned error",
        \\export fn entry() void {
        \\    foo() catch unreachable;
        \\}
        \\fn foo() !void {
        \\}
    ,
        ".tmp_source.zig:4:11: error: function with inferred error set must return at least one possible error",
    );

    cases.add(
        "error not handled in switch",
        \\export fn entry() void {
        \\    foo(452) catch |err| switch (err) {
        \\        error.Foo => {},
        \\    };
        \\}
        \\fn foo(x: i32) !void {
        \\    switch (x) {
        \\        0 ... 10 => return error.Foo,
        \\        11 ... 20 => return error.Bar,
        \\        21 ... 30 => return error.Baz,
        \\        else => {},
        \\    }
        \\}
    ,
        ".tmp_source.zig:2:26: error: error.Baz not handled in switch",
        ".tmp_source.zig:2:26: error: error.Bar not handled in switch",
    );

    cases.add(
        "duplicate error in switch",
        \\export fn entry() void {
        \\    foo(452) catch |err| switch (err) {
        \\        error.Foo => {},
        \\        error.Bar => {},
        \\        error.Foo => {},
        \\        else => {},
        \\    };
        \\}
        \\fn foo(x: i32) !void {
        \\    switch (x) {
        \\        0 ... 10 => return error.Foo,
        \\        11 ... 20 => return error.Bar,
        \\        else => {},
        \\    }
        \\}
    ,
        ".tmp_source.zig:5:14: error: duplicate switch value: '@typeOf(foo).ReturnType.ErrorSet.Foo'",
        ".tmp_source.zig:3:14: note: other value is here",
    );

    cases.add("invalid cast from integral type to enum",
        \\const E = enum(usize) { One, Two };
        \\
        \\export fn entry() void {
        \\    foo(1);
        \\}
        \\
        \\fn foo(x: usize) void {
        \\    switch (x) {
        \\        E.One => {},
        \\    }
        \\}
    , ".tmp_source.zig:9:10: error: expected type 'usize', found 'E'");

    cases.add(
        "range operator in switch used on error set",
        \\export fn entry() void {
        \\    try foo(452) catch |err| switch (err) {
        \\        error.A ... error.B => {},
        \\        else => {},
        \\    };
        \\}
        \\fn foo(x: i32) !void {
        \\    switch (x) {
        \\        0 ... 10 => return error.Foo,
        \\        11 ... 20 => return error.Bar,
        \\        else => {},
        \\    }
        \\}
    ,
        ".tmp_source.zig:3:17: error: operator not allowed for errors",
    );

    cases.add(
        "inferring error set of function pointer",
        \\comptime {
        \\    const z: ?fn()!void = null;
        \\}
    ,
        ".tmp_source.zig:2:15: error: inferring error set of return type valid only for function definitions",
    );

    cases.add(
        "access non-existent member of error set",
        \\const Foo = error{A};
        \\comptime {
        \\    const z = Foo.Bar;
        \\}
    ,
        ".tmp_source.zig:3:18: error: no error named 'Bar' in 'Foo'",
    );

    cases.add(
        "error union operator with non error set LHS",
        \\comptime {
        \\    const z = i32!i32;
        \\}
    ,
        ".tmp_source.zig:2:15: error: expected error set type, found type 'i32'",
    );

    cases.add(
        "error equality but sets have no common members",
        \\const Set1 = error{A, C};
        \\const Set2 = error{B, D};
        \\export fn entry() void {
        \\    foo(Set1.A);
        \\}
        \\fn foo(x: Set1) void {
        \\    if (x == Set2.B) {
        \\
        \\    }
        \\}
    ,
        ".tmp_source.zig:7:11: error: error sets 'Set1' and 'Set2' have no common errors",
    );

    cases.add(
        "only equality binary operator allowed for error sets",
        \\comptime {
        \\    const z = error.A > error.B;
        \\}
    ,
        ".tmp_source.zig:2:23: error: operator not allowed for errors",
    );

    cases.add(
        "explicit error set cast known at comptime violates error sets",
        \\const Set1 = error {A, B};
        \\const Set2 = error {A, C};
        \\comptime {
        \\    var x = Set1.B;
        \\    var y = @errSetCast(Set2, x);
        \\}
    ,
        ".tmp_source.zig:5:13: error: error.B not a member of error set 'Set2'",
    );

    cases.add(
        "cast error union of global error set to error union of smaller error set",
        \\const SmallErrorSet = error{A};
        \\export fn entry() void {
        \\    var x: SmallErrorSet!i32 = foo();
        \\}
        \\fn foo() error!i32 {
        \\    return error.B;
        \\}
    ,
        ".tmp_source.zig:3:35: error: expected type 'SmallErrorSet!i32', found 'error!i32'",
        ".tmp_source.zig:3:35: note: error set 'error' cannot cast into error set 'SmallErrorSet'",
        ".tmp_source.zig:3:35: note: cannot cast global error set into smaller set",
    );

    cases.add(
        "cast global error set to error set",
        \\const SmallErrorSet = error{A};
        \\export fn entry() void {
        \\    var x: SmallErrorSet = foo();
        \\}
        \\fn foo() error {
        \\    return error.B;
        \\}
    ,
        ".tmp_source.zig:3:31: error: expected type 'SmallErrorSet', found 'error'",
        ".tmp_source.zig:3:31: note: cannot cast global error set into smaller set",
    );

    cases.add(
        "recursive inferred error set",
        \\export fn entry() void {
        \\    foo() catch unreachable;
        \\}
        \\fn foo() !void {
        \\    try foo();
        \\}
    ,
        ".tmp_source.zig:5:5: error: cannot resolve inferred error set '@typeOf(foo).ReturnType.ErrorSet': function 'foo' not fully analyzed yet",
    );

    cases.add(
        "implicit cast of error set not a subset",
        \\const Set1 = error{A, B};
        \\const Set2 = error{A, C};
        \\export fn entry() void {
        \\    foo(Set1.B);
        \\}
        \\fn foo(set1: Set1) void {
        \\    var x: Set2 = set1;
        \\}
    ,
        ".tmp_source.zig:7:19: error: expected type 'Set2', found 'Set1'",
        ".tmp_source.zig:1:23: note: 'error.B' not a member of destination error set",
    );

    cases.add(
        "int to err global invalid number",
        \\const Set1 = error{
        \\    A,
        \\    B,
        \\};
        \\comptime {
        \\    var x: u16 = 3;
        \\    var y = @intToError(x);
        \\}
    ,
        ".tmp_source.zig:7:13: error: integer value 3 represents no error",
    );

    cases.add(
        "int to err non global invalid number",
        \\const Set1 = error{
        \\    A,
        \\    B,
        \\};
        \\const Set2 = error{
        \\    A,
        \\    C,
        \\};
        \\comptime {
        \\    var x = @errorToInt(Set1.B);
        \\    var y = @errSetCast(Set2, @intToError(x));
        \\}
    ,
        ".tmp_source.zig:11:13: error: error.B not a member of error set 'Set2'",
    );

    cases.add(
        "@memberCount of error",
        \\comptime {
        \\    _ = @memberCount(error);
        \\}
    ,
        ".tmp_source.zig:2:9: error: global error set member count not available at comptime",
    );

    cases.add(
        "duplicate error value in error set",
        \\const Foo = error {
        \\    Bar,
        \\    Bar,
        \\};
        \\export fn entry() void {
        \\    const a: Foo = undefined;
        \\}
    ,
        ".tmp_source.zig:3:5: error: duplicate error: 'Bar'",
        ".tmp_source.zig:2:5: note: other error here",
    );

    cases.add(
        "cast negative integer literal to usize",
        \\export fn entry() void {
        \\    const x = usize(-10);
        \\}
    ,
        ".tmp_source.zig:2:21: error: cannot cast negative value -10 to unsigned integer type 'usize'",
    );

    cases.add(
        "use invalid number literal as array index",
        \\var v = 25;
        \\export fn entry() void {
        \\    var arr: [v]u8 = undefined;
        \\}
    ,
        ".tmp_source.zig:1:1: error: unable to infer variable type",
    );

    cases.add(
        "duplicate struct field",
        \\const Foo = struct {
        \\    Bar: i32,
        \\    Bar: usize,
        \\};
        \\export fn entry() void {
        \\    const a: Foo = undefined;
        \\}
    ,
        ".tmp_source.zig:3:5: error: duplicate struct field: 'Bar'",
        ".tmp_source.zig:2:5: note: other field here",
    );

    cases.add(
        "duplicate union field",
        \\const Foo = union {
        \\    Bar: i32,
        \\    Bar: usize,
        \\};
        \\export fn entry() void {
        \\    const a: Foo = undefined;
        \\}
    ,
        ".tmp_source.zig:3:5: error: duplicate union field: 'Bar'",
        ".tmp_source.zig:2:5: note: other field here",
    );

    cases.add(
        "duplicate enum field",
        \\const Foo = enum {
        \\    Bar,
        \\    Bar,
        \\};
        \\
        \\export fn entry() void {
        \\    const a: Foo = undefined;
        \\}
    ,
        ".tmp_source.zig:3:5: error: duplicate enum field: 'Bar'",
        ".tmp_source.zig:2:5: note: other field here",
    );

    cases.add(
        "calling function with naked calling convention",
        \\export fn entry() void {
        \\    foo();
        \\}
        \\nakedcc fn foo() void { }
    ,
        ".tmp_source.zig:2:5: error: unable to call function with naked calling convention",
        ".tmp_source.zig:4:9: note: declared here",
    );

    cases.add(
        "function with invalid return type",
        \\export fn foo() boid {}
    ,
        ".tmp_source.zig:1:17: error: use of undeclared identifier 'boid'",
    );

    cases.add(
        "function with non-extern non-packed enum parameter",
        \\const Foo = enum { A, B, C };
        \\export fn entry(foo: Foo) void { }
    ,
        ".tmp_source.zig:2:22: error: parameter of type 'Foo' not allowed in function with calling convention 'ccc'",
    );

    cases.add(
        "function with non-extern non-packed struct parameter",
        \\const Foo = struct {
        \\    A: i32,
        \\    B: f32,
        \\    C: bool,
        \\};
        \\export fn entry(foo: Foo) void { }
    ,
        ".tmp_source.zig:6:22: error: parameter of type 'Foo' not allowed in function with calling convention 'ccc'",
    );

    cases.add(
        "function with non-extern non-packed union parameter",
        \\const Foo = union {
        \\    A: i32,
        \\    B: f32,
        \\    C: bool,
        \\};
        \\export fn entry(foo: Foo) void { }
    ,
        ".tmp_source.zig:6:22: error: parameter of type 'Foo' not allowed in function with calling convention 'ccc'",
    );

    cases.add(
        "switch on enum with 1 field with no prongs",
        \\const Foo = enum { M };
        \\
        \\export fn entry() void {
        \\    var f = Foo.M;
        \\    switch (f) {}
        \\}
    ,
        ".tmp_source.zig:5:5: error: enumeration value 'Foo.M' not handled in switch",
    );

    cases.add(
        "shift by negative comptime integer",
        \\comptime {
        \\    var a = 1 >> -1;
        \\}
    ,
        ".tmp_source.zig:2:18: error: shift by negative value -1",
    );

    cases.add(
        "@panic called at compile time",
        \\export fn entry() void {
        \\    comptime {
        \\        @panic("aoeu",);
        \\    }
        \\}
    ,
        ".tmp_source.zig:3:9: error: encountered @panic at compile-time",
    );

    cases.add(
        "wrong return type for main",
        \\pub fn main() f32 { }
    ,
        "error: expected return type of main to be 'u8', 'noreturn', 'void', or '!void'",
    );

    cases.add(
        "double ?? on main return value",
        \\pub fn main() ??void {
        \\}
    ,
        "error: expected return type of main to be 'u8', 'noreturn', 'void', or '!void'",
    );

    cases.add(
        "bad identifier in function with struct defined inside function which references local const",
        \\export fn entry() void {
        \\    const BlockKind = u32;
        \\
        \\    const Block = struct {
        \\        kind: BlockKind,
        \\    };
        \\
        \\    bogus;
        \\}
    ,
        ".tmp_source.zig:8:5: error: use of undeclared identifier 'bogus'",
    );

    cases.add(
        "labeled break not found",
        \\export fn entry() void {
        \\    blah: while (true) {
        \\        while (true) {
        \\            break :outer;
        \\        }
        \\    }
        \\}
    ,
        ".tmp_source.zig:4:13: error: label not found: 'outer'",
    );

    cases.add(
        "labeled continue not found",
        \\export fn entry() void {
        \\    var i: usize = 0;
        \\    blah: while (i < 10) : (i += 1) {
        \\        while (true) {
        \\            continue :outer;
        \\        }
        \\    }
        \\}
    ,
        ".tmp_source.zig:5:13: error: labeled loop not found: 'outer'",
    );

    cases.add(
        "attempt to use 0 bit type in extern fn",
        \\extern fn foo(ptr: extern fn(*void) void) void;
        \\
        \\export fn entry() void {
        \\    foo(bar);
        \\}
        \\
        \\extern fn bar(x: *void) void { }
    ,
        ".tmp_source.zig:7:18: error: parameter of type '*void' has 0 bits; not allowed in function with calling convention 'ccc'",
    );

    cases.add(
        "implicit semicolon - block statement",
        \\export fn entry() void {
        \\    {}
        \\    var good = {};
        \\    ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - block expr",
        \\export fn entry() void {
        \\    _ = {};
        \\    var good = {};
        \\    _ = {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - comptime statement",
        \\export fn entry() void {
        \\    comptime {}
        \\    var good = {};
        \\    comptime ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - comptime expression",
        \\export fn entry() void {
        \\    _ = comptime {};
        \\    var good = {};
        \\    _ = comptime {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - defer",
        \\export fn entry() void {
        \\    defer {}
        \\    var good = {};
        \\    defer ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - if statement",
        \\export fn entry() void {
        \\    if(true) {}
        \\    var good = {};
        \\    if(true) ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - if expression",
        \\export fn entry() void {
        \\    _ = if(true) {};
        \\    var good = {};
        \\    _ = if(true) {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - if-else statement",
        \\export fn entry() void {
        \\    if(true) {} else {}
        \\    var good = {};
        \\    if(true) ({}) else ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - if-else expression",
        \\export fn entry() void {
        \\    _ = if(true) {} else {};
        \\    var good = {};
        \\    _ = if(true) {} else {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - if-else-if statement",
        \\export fn entry() void {
        \\    if(true) {} else if(true) {}
        \\    var good = {};
        \\    if(true) ({}) else if(true) ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - if-else-if expression",
        \\export fn entry() void {
        \\    _ = if(true) {} else if(true) {};
        \\    var good = {};
        \\    _ = if(true) {} else if(true) {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - if-else-if-else statement",
        \\export fn entry() void {
        \\    if(true) {} else if(true) {} else {}
        \\    var good = {};
        \\    if(true) ({}) else if(true) ({}) else ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - if-else-if-else expression",
        \\export fn entry() void {
        \\    _ = if(true) {} else if(true) {} else {};
        \\    var good = {};
        \\    _ = if(true) {} else if(true) {} else {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - test statement",
        \\export fn entry() void {
        \\    if (foo()) |_| {}
        \\    var good = {};
        \\    if (foo()) |_| ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - test expression",
        \\export fn entry() void {
        \\    _ = if (foo()) |_| {};
        \\    var good = {};
        \\    _ = if (foo()) |_| {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - while statement",
        \\export fn entry() void {
        \\    while(true) {}
        \\    var good = {};
        \\    while(true) ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - while expression",
        \\export fn entry() void {
        \\    _ = while(true) {};
        \\    var good = {};
        \\    _ = while(true) {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - while-continue statement",
        \\export fn entry() void {
        \\    while(true):({}) {}
        \\    var good = {};
        \\    while(true):({}) ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - while-continue expression",
        \\export fn entry() void {
        \\    _ = while(true):({}) {};
        \\    var good = {};
        \\    _ = while(true):({}) {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - for statement",
        \\export fn entry() void {
        \\    for(foo()) {}
        \\    var good = {};
        \\    for(foo()) ({})
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "implicit semicolon - for expression",
        \\export fn entry() void {
        \\    _ = for(foo()) {};
        \\    var good = {};
        \\    _ = for(foo()) {}
        \\    var bad = {};
        \\}
    ,
        ".tmp_source.zig:5:5: error: expected token ';', found 'var'",
    );

    cases.add(
        "multiple function definitions",
        \\fn a() void {}
        \\fn a() void {}
        \\export fn entry() void { a(); }
    ,
        ".tmp_source.zig:2:1: error: redefinition of 'a'",
    );

    cases.add(
        "unreachable with return",
        \\fn a() noreturn {return;}
        \\export fn entry() void { a(); }
    ,
        ".tmp_source.zig:1:18: error: expected type 'noreturn', found 'void'",
    );

    cases.add(
        "control reaches end of non-void function",
        \\fn a() i32 {}
        \\export fn entry() void { _ = a(); }
    ,
        ".tmp_source.zig:1:12: error: expected type 'i32', found 'void'",
    );

    cases.add(
        "undefined function call",
        \\export fn a() void {
        \\    b();
        \\}
    ,
        ".tmp_source.zig:2:5: error: use of undeclared identifier 'b'",
    );

    cases.add(
        "wrong number of arguments",
        \\export fn a() void {
        \\    b(1);
        \\}
        \\fn b(a: i32, b: i32, c: i32) void { }
    ,
        ".tmp_source.zig:2:6: error: expected 3 arguments, found 1",
    );

    cases.add(
        "invalid type",
        \\fn a() bogus {}
        \\export fn entry() void { _ = a(); }
    ,
        ".tmp_source.zig:1:8: error: use of undeclared identifier 'bogus'",
    );

    cases.add(
        "pointer to noreturn",
        \\fn a() *noreturn {}
        \\export fn entry() void { _ = a(); }
    ,
        ".tmp_source.zig:1:8: error: pointer to noreturn not allowed",
    );

    cases.add(
        "unreachable code",
        \\export fn a() void {
        \\    return;
        \\    b();
        \\}
        \\
        \\fn b() void {}
    ,
        ".tmp_source.zig:3:5: error: unreachable code",
    );

    cases.add(
        "bad import",
        \\const bogus = @import("bogus-does-not-exist.zig",);
        \\export fn entry() void { bogus.bogo(); }
    ,
        ".tmp_source.zig:1:15: error: unable to find 'bogus-does-not-exist.zig'",
    );

    cases.add(
        "undeclared identifier",
        \\export fn a() void {
        \\    return
        \\    b +
        \\    c;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undeclared identifier 'b'",
        ".tmp_source.zig:4:5: error: use of undeclared identifier 'c'",
    );

    cases.add(
        "parameter redeclaration",
        \\fn f(a : i32, a : i32) void {
        \\}
        \\export fn entry() void { f(1, 2); }
    ,
        ".tmp_source.zig:1:15: error: redeclaration of variable 'a'",
    );

    cases.add(
        "local variable redeclaration",
        \\export fn f() void {
        \\    const a : i32 = 0;
        \\    const a = 0;
        \\}
    ,
        ".tmp_source.zig:3:5: error: redeclaration of variable 'a'",
    );

    cases.add(
        "local variable redeclares parameter",
        \\fn f(a : i32) void {
        \\    const a = 0;
        \\}
        \\export fn entry() void { f(1); }
    ,
        ".tmp_source.zig:2:5: error: redeclaration of variable 'a'",
    );

    cases.add(
        "variable has wrong type",
        \\export fn f() i32 {
        \\    const a = c"a";
        \\    return a;
        \\}
    ,
        ".tmp_source.zig:3:12: error: expected type 'i32', found '[*]const u8'",
    );

    cases.add(
        "if condition is bool, not int",
        \\export fn f() void {
        \\    if (0) {}
        \\}
    ,
        ".tmp_source.zig:2:9: error: integer value 0 cannot be implicitly casted to type 'bool'",
    );

    cases.add(
        "assign unreachable",
        \\export fn f() void {
        \\    const a = return;
        \\}
    ,
        ".tmp_source.zig:2:5: error: unreachable code",
    );

    cases.add(
        "unreachable variable",
        \\export fn f() void {
        \\    const a: noreturn = {};
        \\}
    ,
        ".tmp_source.zig:2:14: error: variable of type 'noreturn' not allowed",
    );

    cases.add(
        "unreachable parameter",
        \\fn f(a: noreturn) void {}
        \\export fn entry() void { f(); }
    ,
        ".tmp_source.zig:1:9: error: parameter of type 'noreturn' not allowed",
    );

    cases.add(
        "bad assignment target",
        \\export fn f() void {
        \\    3 = 3;
        \\}
    ,
        ".tmp_source.zig:2:7: error: cannot assign to constant",
    );

    cases.add(
        "assign to constant variable",
        \\export fn f() void {
        \\    const a = 3;
        \\    a = 4;
        \\}
    ,
        ".tmp_source.zig:3:7: error: cannot assign to constant",
    );

    cases.add(
        "use of undeclared identifier",
        \\export fn f() void {
        \\    b = 3;
        \\}
    ,
        ".tmp_source.zig:2:5: error: use of undeclared identifier 'b'",
    );

    cases.add(
        "const is a statement, not an expression",
        \\export fn f() void {
        \\    (const a = 0);
        \\}
    ,
        ".tmp_source.zig:2:6: error: invalid token: 'const'",
    );

    cases.add(
        "array access of undeclared identifier",
        \\export fn f() void {
        \\    i[i] = i[i];
        \\}
    ,
        ".tmp_source.zig:2:5: error: use of undeclared identifier 'i'",
        ".tmp_source.zig:2:12: error: use of undeclared identifier 'i'",
    );

    cases.add(
        "array access of non array",
        \\export fn f() void {
        \\    var bad : bool = undefined;
        \\    bad[bad] = bad[bad];
        \\}
    ,
        ".tmp_source.zig:3:8: error: array access of non-array type 'bool'",
        ".tmp_source.zig:3:19: error: array access of non-array type 'bool'",
    );

    cases.add(
        "array access with non integer index",
        \\export fn f() void {
        \\    var array = "aoeu";
        \\    var bad = false;
        \\    array[bad] = array[bad];
        \\}
    ,
        ".tmp_source.zig:4:11: error: expected type 'usize', found 'bool'",
        ".tmp_source.zig:4:24: error: expected type 'usize', found 'bool'",
    );

    cases.add(
        "write to const global variable",
        \\const x : i32 = 99;
        \\fn f() void {
        \\    x = 1;
        \\}
        \\export fn entry() void { f(); }
    ,
        ".tmp_source.zig:3:7: error: cannot assign to constant",
    );

    cases.add(
        "missing else clause",
        \\fn f(b: bool) void {
        \\    const x : i32 = if (b) h: { break :h 1; };
        \\    const y = if (b) h: { break :h i32(1); };
        \\}
        \\export fn entry() void { f(true); }
    ,
        ".tmp_source.zig:2:42: error: integer value 1 cannot be implicitly casted to type 'void'",
        ".tmp_source.zig:3:15: error: incompatible types: 'i32' and 'void'",
    );

    cases.add(
        "direct struct loop",
        \\const A = struct { a : A, };
        \\export fn entry() usize { return @sizeOf(A); }
    ,
        ".tmp_source.zig:1:11: error: struct 'A' contains itself",
    );

    cases.add(
        "indirect struct loop",
        \\const A = struct { b : B, };
        \\const B = struct { c : C, };
        \\const C = struct { a : A, };
        \\export fn entry() usize { return @sizeOf(A); }
    ,
        ".tmp_source.zig:1:11: error: struct 'A' contains itself",
    );

    cases.add(
        "invalid struct field",
        \\const A = struct { x : i32, };
        \\export fn f() void {
        \\    var a : A = undefined;
        \\    a.foo = 1;
        \\    const y = a.bar;
        \\}
    ,
        ".tmp_source.zig:4:6: error: no member named 'foo' in struct 'A'",
        ".tmp_source.zig:5:16: error: no member named 'bar' in struct 'A'",
    );

    cases.add(
        "redefinition of struct",
        \\const A = struct { x : i32, };
        \\const A = struct { y : i32, };
    ,
        ".tmp_source.zig:2:1: error: redefinition of 'A'",
    );

    cases.add(
        "redefinition of enums",
        \\const A = enum {};
        \\const A = enum {};
    ,
        ".tmp_source.zig:2:1: error: redefinition of 'A'",
    );

    cases.add(
        "redefinition of global variables",
        \\var a : i32 = 1;
        \\var a : i32 = 2;
    ,
        ".tmp_source.zig:2:1: error: redefinition of 'a'",
        ".tmp_source.zig:1:1: note: previous definition is here",
    );

    cases.add(
        "duplicate field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\export fn f() void {
        \\    const a = A {
        \\        .z = 1,
        \\        .y = 2,
        \\        .x = 3,
        \\        .z = 4,
        \\    };
        \\}
    ,
        ".tmp_source.zig:11:9: error: duplicate field",
    );

    cases.add(
        "missing field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\export fn f() void {
        \\    // we want the error on the '{' not the 'A' because
        \\    // the A could be a complicated expression
        \\    const a = A {
        \\        .z = 4,
        \\        .y = 2,
        \\    };
        \\}
    ,
        ".tmp_source.zig:9:17: error: missing field: 'x'",
    );

    cases.add(
        "invalid field in struct value expression",
        \\const A = struct {
        \\    x : i32,
        \\    y : i32,
        \\    z : i32,
        \\};
        \\export fn f() void {
        \\    const a = A {
        \\        .z = 4,
        \\        .y = 2,
        \\        .foo = 42,
        \\    };
        \\}
    ,
        ".tmp_source.zig:10:9: error: no member named 'foo' in struct 'A'",
    );

    cases.add(
        "invalid break expression",
        \\export fn f() void {
        \\    break;
        \\}
    ,
        ".tmp_source.zig:2:5: error: break expression outside loop",
    );

    cases.add(
        "invalid continue expression",
        \\export fn f() void {
        \\    continue;
        \\}
    ,
        ".tmp_source.zig:2:5: error: continue expression outside loop",
    );

    cases.add(
        "invalid maybe type",
        \\export fn f() void {
        \\    if (true) |x| { }
        \\}
    ,
        ".tmp_source.zig:2:9: error: expected optional type, found 'bool'",
    );

    cases.add(
        "cast unreachable",
        \\fn f() i32 {
        \\    return i32(return 1);
        \\}
        \\export fn entry() void { _ = f(); }
    ,
        ".tmp_source.zig:2:15: error: unreachable code",
    );

    cases.add(
        "invalid builtin fn",
        \\fn f() @bogus(foo) {
        \\}
        \\export fn entry() void { _ = f(); }
    ,
        ".tmp_source.zig:1:8: error: invalid builtin function: 'bogus'",
    );

    cases.add(
        "top level decl dependency loop",
        \\const a : @typeOf(b) = 0;
        \\const b : @typeOf(a) = 0;
        \\export fn entry() void {
        \\    const c = a + b;
        \\}
    ,
        ".tmp_source.zig:1:1: error: 'a' depends on itself",
    );

    cases.add(
        "noalias on non pointer param",
        \\fn f(noalias x: i32) void {}
        \\export fn entry() void { f(1234); }
    ,
        ".tmp_source.zig:1:6: error: noalias on non-pointer parameter",
    );

    cases.add(
        "struct init syntax for array",
        \\const foo = []u16{.x = 1024,};
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:1:18: error: type '[]u16' does not support struct initialization syntax",
    );

    cases.add(
        "type variables must be constant",
        \\var foo = u8;
        \\export fn entry() foo {
        \\    return 1;
        \\}
    ,
        ".tmp_source.zig:1:1: error: variable of type 'type' must be constant",
    );

    cases.add(
        "variables shadowing types",
        \\const Foo = struct {};
        \\const Bar = struct {};
        \\
        \\fn f(Foo: i32) void {
        \\    var Bar : i32 = undefined;
        \\}
        \\
        \\export fn entry() void {
        \\    f(1234);
        \\}
    ,
        ".tmp_source.zig:4:6: error: redefinition of 'Foo'",
        ".tmp_source.zig:1:1: note: previous definition is here",
        ".tmp_source.zig:5:5: error: redefinition of 'Bar'",
        ".tmp_source.zig:2:1: note: previous definition is here",
    );

    cases.add(
        "switch expression - missing enumeration prong",
        \\const Number = enum {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\fn f(n: Number) i32 {
        \\    switch (n) {
        \\        Number.One => 1,
        \\        Number.Two => 2,
        \\        Number.Three => i32(3),
        \\    }
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:8:5: error: enumeration value 'Number.Four' not handled in switch",
    );

    cases.add(
        "switch expression - duplicate enumeration prong",
        \\const Number = enum {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\fn f(n: Number) i32 {
        \\    switch (n) {
        \\        Number.One => 1,
        \\        Number.Two => 2,
        \\        Number.Three => i32(3),
        \\        Number.Four => 4,
        \\        Number.Two => 2,
        \\    }
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:13:15: error: duplicate switch value",
        ".tmp_source.zig:10:15: note: other value is here",
    );

    cases.add(
        "switch expression - duplicate enumeration prong when else present",
        \\const Number = enum {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\fn f(n: Number) i32 {
        \\    switch (n) {
        \\        Number.One => 1,
        \\        Number.Two => 2,
        \\        Number.Three => i32(3),
        \\        Number.Four => 4,
        \\        Number.Two => 2,
        \\        else => 10,
        \\    }
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:13:15: error: duplicate switch value",
        ".tmp_source.zig:10:15: note: other value is here",
    );

    cases.add(
        "switch expression - multiple else prongs",
        \\fn f(x: u32) void {
        \\    const value: bool = switch (x) {
        \\        1234 => false,
        \\        else => true,
        \\        else => true,
        \\    };
        \\}
        \\export fn entry() void {
        \\    f(1234);
        \\}
    ,
        ".tmp_source.zig:5:9: error: multiple else prongs in switch expression",
    );

    cases.add(
        "switch expression - non exhaustive integer prongs",
        \\fn foo(x: u8) void {
        \\    switch (x) {
        \\        0 => {},
        \\    }
        \\}
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:2:5: error: switch must handle all possibilities",
    );

    cases.add(
        "switch expression - duplicate or overlapping integer value",
        \\fn foo(x: u8) u8 {
        \\    return switch (x) {
        \\        0 ... 100 => u8(0),
        \\        101 ... 200 => 1,
        \\        201, 203 ... 207 => 2,
        \\        206 ... 255 => 3,
        \\    };
        \\}
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:6:9: error: duplicate switch value",
        ".tmp_source.zig:5:14: note: previous value is here",
    );

    cases.add(
        "switch expression - switch on pointer type with no else",
        \\fn foo(x: *u8) void {
        \\    switch (x) {
        \\        &y => {},
        \\    }
        \\}
        \\const y: u8 = 100;
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:2:5: error: else prong required when switching on type '*u8'",
    );

    cases.add(
        "global variable initializer must be constant expression",
        \\extern fn foo() i32;
        \\const x = foo();
        \\export fn entry() i32 { return x; }
    ,
        ".tmp_source.zig:2:11: error: unable to evaluate constant expression",
    );

    cases.add(
        "array concatenation with wrong type",
        \\const src = "aoeu";
        \\const derp = usize(1234);
        \\const a = derp ++ "foo";
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(a)); }
    ,
        ".tmp_source.zig:3:11: error: expected array or C string literal, found 'usize'",
    );

    cases.add(
        "non compile time array concatenation",
        \\fn f() []u8 {
        \\    return s ++ "foo";
        \\}
        \\var s: [10]u8 = undefined;
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:2:12: error: unable to evaluate constant expression",
    );

    cases.add(
        "@cImport with bogus include",
        \\const c = @cImport(@cInclude("bogus.h"));
        \\export fn entry() usize { return @sizeOf(@typeOf(c.bogo)); }
    ,
        ".tmp_source.zig:1:11: error: C import failed",
        ".h:1:10: note: 'bogus.h' file not found",
    );

    cases.add(
        "address of number literal",
        \\const x = 3;
        \\const y = &x;
        \\fn foo() *const i32 { return y; }
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:3:30: error: expected type '*const i32', found '*const comptime_int'",
    );

    cases.add(
        "integer overflow error",
        \\const x : u8 = 300;
        \\export fn entry() usize { return @sizeOf(@typeOf(x)); }
    ,
        ".tmp_source.zig:1:16: error: integer value 300 cannot be implicitly casted to type 'u8'",
    );

    cases.add(
        "invalid shift amount error",
        \\const x : u8 = 2;
        \\fn f() u16 {
        \\    return x << 8;
        \\}
        \\export fn entry() u16 { return f(); }
    ,
        ".tmp_source.zig:3:14: error: RHS of shift is too large for LHS type",
        ".tmp_source.zig:3:17: note: value 8 cannot fit into type u3",
    );

    cases.add(
        "incompatible number literals",
        \\const x = 2 == 2.0;
        \\export fn entry() usize { return @sizeOf(@typeOf(x)); }
    ,
        ".tmp_source.zig:1:11: error: integer value 2 cannot be implicitly casted to type 'comptime_float'",
    );

    cases.add(
        "missing function call param",
        \\const Foo = struct {
        \\    a: i32,
        \\    b: i32,
        \\
        \\    fn member_a(foo: *const Foo) i32 {
        \\        return foo.a;
        \\    }
        \\    fn member_b(foo: *const Foo) i32 {
        \\        return foo.b;
        \\    }
        \\};
        \\
        \\const member_fn_type = @typeOf(Foo.member_a);
        \\const members = []member_fn_type {
        \\    Foo.member_a,
        \\    Foo.member_b,
        \\};
        \\
        \\fn f(foo: *const Foo, index: usize) void {
        \\    const result = members[index]();
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:20:34: error: expected 1 arguments, found 0",
    );

    cases.add(
        "missing function name and param name",
        \\fn () void {}
        \\fn f(i32) void {}
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:1:1: error: missing function name",
        ".tmp_source.zig:2:6: error: missing parameter name",
    );

    cases.add(
        "wrong function type",
        \\const fns = []fn() void { a, b, c };
        \\fn a() i32 {return 0;}
        \\fn b() i32 {return 1;}
        \\fn c() i32 {return 2;}
        \\export fn entry() usize { return @sizeOf(@typeOf(fns)); }
    ,
        ".tmp_source.zig:1:27: error: expected type 'fn() void', found 'fn() i32'",
    );

    cases.add(
        "extern function pointer mismatch",
        \\const fns = [](fn(i32)i32) { a, b, c };
        \\pub fn a(x: i32) i32 {return x + 0;}
        \\pub fn b(x: i32) i32 {return x + 1;}
        \\export fn c(x: i32) i32 {return x + 2;}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(fns)); }
    ,
        ".tmp_source.zig:1:36: error: expected type 'fn(i32) i32', found 'extern fn(i32) i32'",
    );

    cases.add(
        "implicit cast from f64 to f32",
        \\const x : f64 = 1.0;
        \\const y : f32 = x;
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(y)); }
    ,
        ".tmp_source.zig:2:17: error: expected type 'f32', found 'f64'",
    );

    cases.add(
        "colliding invalid top level functions",
        \\fn func() bogus {}
        \\fn func() bogus {}
        \\export fn entry() usize { return @sizeOf(@typeOf(func)); }
    ,
        ".tmp_source.zig:2:1: error: redefinition of 'func'",
        ".tmp_source.zig:1:11: error: use of undeclared identifier 'bogus'",
    );

    cases.add(
        "bogus compile var",
        \\const x = @import("builtin").bogus;
        \\export fn entry() usize { return @sizeOf(@typeOf(x)); }
    ,
        ".tmp_source.zig:1:29: error: no member named 'bogus' in '",
    );

    cases.add(
        "non constant expression in array size outside function",
        \\const Foo = struct {
        \\    y: [get()]u8,
        \\};
        \\var global_var: usize = 1;
        \\fn get() usize { return global_var; }
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(Foo)); }
    ,
        ".tmp_source.zig:5:25: error: unable to evaluate constant expression",
        ".tmp_source.zig:2:12: note: called from here",
        ".tmp_source.zig:2:8: note: called from here",
    );

    cases.add(
        "addition with non numbers",
        \\const Foo = struct {
        \\    field: i32,
        \\};
        \\const x = Foo {.field = 1} + Foo {.field = 2};
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(x)); }
    ,
        ".tmp_source.zig:4:28: error: invalid operands to binary expression: 'Foo' and 'Foo'",
    );

    cases.add(
        "division by zero",
        \\const lit_int_x = 1 / 0;
        \\const lit_float_x = 1.0 / 0.0;
        \\const int_x = u32(1) / u32(0);
        \\const float_x = f32(1.0) / f32(0.0);
        \\
        \\export fn entry1() usize { return @sizeOf(@typeOf(lit_int_x)); }
        \\export fn entry2() usize { return @sizeOf(@typeOf(lit_float_x)); }
        \\export fn entry3() usize { return @sizeOf(@typeOf(int_x)); }
        \\export fn entry4() usize { return @sizeOf(@typeOf(float_x)); }
    ,
        ".tmp_source.zig:1:21: error: division by zero",
        ".tmp_source.zig:2:25: error: division by zero",
        ".tmp_source.zig:3:22: error: division by zero",
        ".tmp_source.zig:4:26: error: division by zero",
    );

    cases.add(
        "normal string with newline",
        \\const foo = "a
        \\b";
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:1:13: error: newline not allowed in string literal",
    );

    cases.add(
        "invalid comparison for function pointers",
        \\fn foo() void {}
        \\const invalid = foo > foo;
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(invalid)); }
    ,
        ".tmp_source.zig:2:21: error: operator not allowed for type 'fn() void'",
    );

    cases.add(
        "generic function instance with non-constant expression",
        \\fn foo(comptime x: i32, y: i32) i32 { return x + y; }
        \\fn test1(a: i32, b: i32) i32 {
        \\    return foo(a, b);
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(test1)); }
    ,
        ".tmp_source.zig:3:16: error: unable to evaluate constant expression",
    );

    cases.add(
        "assign null to non-optional pointer",
        \\const a: *u8 = null;
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(a)); }
    ,
        ".tmp_source.zig:1:16: error: expected type '*u8', found '(null)'",
    );

    cases.add(
        "indexing an array of size zero",
        \\const array = []u8{};
        \\export fn foo() void {
        \\    const pointer = &array[0];
        \\}
    ,
        ".tmp_source.zig:3:27: error: index 0 outside array of size 0",
    );

    cases.add(
        "compile time division by zero",
        \\const y = foo(0);
        \\fn foo(x: u32) u32 {
        \\    return 1 / x;
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(y)); }
    ,
        ".tmp_source.zig:3:14: error: division by zero",
        ".tmp_source.zig:1:14: note: called from here",
    );

    cases.add(
        "branch on undefined value",
        \\const x = if (undefined) true else false;
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(x)); }
    ,
        ".tmp_source.zig:1:15: error: use of undefined value",
    );

    cases.add(
        "div on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a / a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "div assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a /= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "mod on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a % a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "mod assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a %= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "add on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a + a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "add assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a += a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "add wrap on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a +% a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "add wrap assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a +%= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "sub on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a - a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "sub assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a -= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "sub wrap on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a -% a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "sub wrap assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a -%= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "mult on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a * a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "mult assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a *= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "mult wrap on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a *% a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "mult wrap assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a *%= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "shift left on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a << 2;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "shift left assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a <<= 2;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "shift right on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a >> 2;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "shift left assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a >>= 2;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "bin and on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a & a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "bin and assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a &= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "bin or on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a | a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "bin or assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a |= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "bin xor on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a ^ a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "bin xor assign on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    a ^= a;
        \\}
    ,
        ".tmp_source.zig:3:5: error: use of undefined value",
    );

    cases.add(
        "equal on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a == a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "not equal on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a != a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "greater than on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a > a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "greater than equal on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a >= a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "less than on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a < a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "less than equal on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = a <= a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "and on undefined value",
        \\comptime {
        \\    var a: bool = undefined;
        \\    _ = a and a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "or on undefined value",
        \\comptime {
        \\    var a: bool = undefined;
        \\    _ = a or a;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "negate on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = -a;
        \\}
    ,
        ".tmp_source.zig:3:10: error: use of undefined value",
    );

    cases.add(
        "negate wrap on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = -%a;
        \\}
    ,
        ".tmp_source.zig:3:11: error: use of undefined value",
    );

    cases.add(
        "bin not on undefined value",
        \\comptime {
        \\    var a: i64 = undefined;
        \\    _ = ~a;
        \\}
    ,
        ".tmp_source.zig:3:10: error: use of undefined value",
    );

    cases.add(
        "bool not on undefined value",
        \\comptime {
        \\    var a: bool = undefined;
        \\    _ = !a;
        \\}
    ,
        ".tmp_source.zig:3:10: error: use of undefined value",
    );

    cases.add(
        "orelse on undefined value",
        \\comptime {
        \\    var a: ?bool = undefined;
        \\    _ = a orelse false;
        \\}
    ,
        ".tmp_source.zig:3:11: error: use of undefined value",
    );

    cases.add(
        "catch on undefined value",
        \\comptime {
        \\    var a: error!bool = undefined;
        \\    _ = a catch |err| false;
        \\}
    ,
        ".tmp_source.zig:3:11: error: use of undefined value",
    );

    cases.add(
        "deref on undefined value",
        \\comptime {
        \\    var a: *u8 = undefined;
        \\    _ = a.*;
        \\}
    ,
        ".tmp_source.zig:3:9: error: use of undefined value",
    );

    cases.add(
        "endless loop in function evaluation",
        \\const seventh_fib_number = fibbonaci(7);
        \\fn fibbonaci(x: i32) i32 {
        \\    return fibbonaci(x - 1) + fibbonaci(x - 2);
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(seventh_fib_number)); }
    ,
        ".tmp_source.zig:3:21: error: evaluation exceeded 1000 backwards branches",
        ".tmp_source.zig:3:21: note: called from here",
    );

    cases.add(
        "@embedFile with bogus file",
        \\const resource = @embedFile("bogus.txt",);
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(resource)); }
    ,
        ".tmp_source.zig:1:29: error: unable to find '",
        "bogus.txt'",
    );

    cases.add(
        "non-const expression in struct literal outside function",
        \\const Foo = struct {
        \\    x: i32,
        \\};
        \\const a = Foo {.x = get_it()};
        \\extern fn get_it() i32;
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(a)); }
    ,
        ".tmp_source.zig:4:21: error: unable to evaluate constant expression",
    );

    cases.add(
        "non-const expression function call with struct return value outside function",
        \\const Foo = struct {
        \\    x: i32,
        \\};
        \\const a = get_it();
        \\fn get_it() Foo {
        \\    global_side_effect = true;
        \\    return Foo {.x = 13};
        \\}
        \\var global_side_effect = false;
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(a)); }
    ,
        ".tmp_source.zig:6:24: error: unable to evaluate constant expression",
        ".tmp_source.zig:4:17: note: called from here",
    );

    cases.add(
        "undeclared identifier error should mark fn as impure",
        \\export fn foo() void {
        \\    test_a_thing();
        \\}
        \\fn test_a_thing() void {
        \\    bad_fn_call();
        \\}
    ,
        ".tmp_source.zig:5:5: error: use of undeclared identifier 'bad_fn_call'",
    );

    cases.add(
        "illegal comparison of types",
        \\fn bad_eql_1(a: []u8, b: []u8) bool {
        \\    return a == b;
        \\}
        \\const EnumWithData = union(enum) {
        \\    One: void,
        \\    Two: i32,
        \\};
        \\fn bad_eql_2(a: *const EnumWithData, b: *const EnumWithData) bool {
        \\    return a.* == b.*;
        \\}
        \\
        \\export fn entry1() usize { return @sizeOf(@typeOf(bad_eql_1)); }
        \\export fn entry2() usize { return @sizeOf(@typeOf(bad_eql_2)); }
    ,
        ".tmp_source.zig:2:14: error: operator not allowed for type '[]u8'",
        ".tmp_source.zig:9:16: error: operator not allowed for type 'EnumWithData'",
    );

    cases.add(
        "non-const switch number literal",
        \\export fn foo() void {
        \\    const x = switch (bar()) {
        \\        1, 2 => 1,
        \\        3, 4 => 2,
        \\        else => 3,
        \\    };
        \\}
        \\fn bar() i32 {
        \\    return 2;
        \\}
    ,
        ".tmp_source.zig:2:15: error: unable to infer expression type",
    );

    cases.add(
        "atomic orderings of cmpxchg - failure stricter than success",
        \\const AtomicOrder = @import("builtin").AtomicOrder;
        \\export fn f() void {
        \\    var x: i32 = 1234;
        \\    while (!@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.Monotonic, AtomicOrder.SeqCst)) {}
        \\}
    ,
        ".tmp_source.zig:4:81: error: failure atomic ordering must be no stricter than success",
    );

    cases.add(
        "atomic orderings of cmpxchg - success Monotonic or stricter",
        \\const AtomicOrder = @import("builtin").AtomicOrder;
        \\export fn f() void {
        \\    var x: i32 = 1234;
        \\    while (!@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.Unordered, AtomicOrder.Unordered)) {}
        \\}
    ,
        ".tmp_source.zig:4:58: error: success atomic ordering must be Monotonic or stricter",
    );

    cases.add(
        "negation overflow in function evaluation",
        \\const y = neg(-128);
        \\fn neg(x: i8) i8 {
        \\    return -x;
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(y)); }
    ,
        ".tmp_source.zig:3:12: error: negation caused overflow",
        ".tmp_source.zig:1:14: note: called from here",
    );

    cases.add(
        "add overflow in function evaluation",
        \\const y = add(65530, 10);
        \\fn add(a: u16, b: u16) u16 {
        \\    return a + b;
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(y)); }
    ,
        ".tmp_source.zig:3:14: error: operation caused overflow",
        ".tmp_source.zig:1:14: note: called from here",
    );

    cases.add(
        "sub overflow in function evaluation",
        \\const y = sub(10, 20);
        \\fn sub(a: u16, b: u16) u16 {
        \\    return a - b;
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(y)); }
    ,
        ".tmp_source.zig:3:14: error: operation caused overflow",
        ".tmp_source.zig:1:14: note: called from here",
    );

    cases.add(
        "mul overflow in function evaluation",
        \\const y = mul(300, 6000);
        \\fn mul(a: u16, b: u16) u16 {
        \\    return a * b;
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(y)); }
    ,
        ".tmp_source.zig:3:14: error: operation caused overflow",
        ".tmp_source.zig:1:14: note: called from here",
    );

    cases.add(
        "truncate sign mismatch",
        \\fn f() i8 {
        \\    const x: u32 = 10;
        \\    return @truncate(i8, x);
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:3:26: error: expected signed integer type, found 'u32'",
    );

    cases.add(
        "try in function with non error return type",
        \\export fn f() void {
        \\    try something();
        \\}
        \\fn something() error!void { }
    ,
        ".tmp_source.zig:2:5: error: expected type 'void', found 'error'",
    );

    cases.add(
        "invalid pointer for var type",
        \\extern fn ext() usize;
        \\var bytes: [ext()]u8 = undefined;
        \\export fn f() void {
        \\    for (bytes) |*b, i| {
        \\        b.* = u8(i);
        \\    }
        \\}
    ,
        ".tmp_source.zig:2:13: error: unable to evaluate constant expression",
    );

    cases.add(
        "export function with comptime parameter",
        \\export fn foo(comptime x: i32, y: i32) i32{
        \\    return x + y;
        \\}
    ,
        ".tmp_source.zig:1:15: error: comptime parameter not allowed in function with calling convention 'ccc'",
    );

    cases.add(
        "extern function with comptime parameter",
        \\extern fn foo(comptime x: i32, y: i32) i32;
        \\fn f() i32 {
        \\    return foo(1, 2);
        \\}
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:1:15: error: comptime parameter not allowed in function with calling convention 'ccc'",
    );

    cases.add(
        "convert fixed size array to slice with invalid size",
        \\export fn f() void {
        \\    var array: [5]u8 = undefined;
        \\    var foo = @bytesToSlice(u32, array)[0];
        \\}
    ,
        ".tmp_source.zig:3:15: error: unable to convert [5]u8 to []align(1) const u32: size mismatch",
        ".tmp_source.zig:3:29: note: u32 has size 4; remaining bytes: 1",
    );

    cases.add(
        "non-pure function returns type",
        \\var a: u32 = 0;
        \\pub fn List(comptime T: type) type {
        \\    a += 1;
        \\    return SmallList(T, 8);
        \\}
        \\
        \\pub fn SmallList(comptime T: type, comptime STATIC_SIZE: usize) type {
        \\    return struct {
        \\        items: []T,
        \\        length: usize,
        \\        prealloc_items: [STATIC_SIZE]T,
        \\    };
        \\}
        \\
        \\export fn function_with_return_type_type() void {
        \\    var list: List(i32) = undefined;
        \\    list.length = 10;
        \\}
    ,
        ".tmp_source.zig:3:7: error: unable to evaluate constant expression",
        ".tmp_source.zig:16:19: note: called from here",
    );

    cases.add(
        "bogus method call on slice",
        \\var self = "aoeu";
        \\fn f(m: []const u8) void {
        \\    m.copy(u8, self[0..], m);
        \\}
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:3:6: error: no member named 'copy' in '[]const u8'",
    );

    cases.add(
        "wrong number of arguments for method fn call",
        \\const Foo = struct {
        \\    fn method(self: *const Foo, a: i32) void {}
        \\};
        \\fn f(foo: *const Foo) void {
        \\
        \\    foo.method(1, 2);
        \\}
        \\export fn entry() usize { return @sizeOf(@typeOf(f)); }
    ,
        ".tmp_source.zig:6:15: error: expected 2 arguments, found 3",
    );

    cases.add(
        "assign through constant pointer",
        \\export fn f() void {
        \\  var cstr = c"Hat";
        \\  cstr[0] = 'W';
        \\}
    ,
        ".tmp_source.zig:3:11: error: cannot assign to constant",
    );

    cases.add(
        "assign through constant slice",
        \\export fn f() void {
        \\  var cstr: []const u8 = "Hat";
        \\  cstr[0] = 'W';
        \\}
    ,
        ".tmp_source.zig:3:11: error: cannot assign to constant",
    );

    cases.add(
        "main function with bogus args type",
        \\pub fn main(args: [][]bogus) !void {}
    ,
        ".tmp_source.zig:1:23: error: use of undeclared identifier 'bogus'",
    );

    cases.add(
        "for loop missing element param",
        \\fn foo(blah: []u8) void {
        \\    for (blah) { }
        \\}
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:2:5: error: for loop expression missing element parameter",
    );

    cases.add(
        "misspelled type with pointer only reference",
        \\const JasonHM = u8;
        \\const JasonList = *JsonNode;
        \\
        \\const JsonOA = union(enum) {
        \\    JSONArray: JsonList,
        \\    JSONObject: JasonHM,
        \\};
        \\
        \\const JsonType = union(enum) {
        \\    JSONNull: void,
        \\    JSONInteger: isize,
        \\    JSONDouble: f64,
        \\    JSONBool: bool,
        \\    JSONString: []u8,
        \\    JSONArray: void,
        \\    JSONObject: void,
        \\};
        \\
        \\pub const JsonNode = struct {
        \\    kind: JsonType,
        \\    jobject: ?JsonOA,
        \\};
        \\
        \\fn foo() void {
        \\    var jll: JasonList = undefined;
        \\    jll.init(1234);
        \\    var jd = JsonNode {.kind = JsonType.JSONArray , .jobject = JsonOA.JSONArray {jll} };
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:5:16: error: use of undeclared identifier 'JsonList'",
    );

    cases.add(
        "method call with first arg type primitive",
        \\const Foo = struct {
        \\    x: i32,
        \\
        \\    fn init(x: i32) Foo {
        \\        return Foo {
        \\            .x = x,
        \\        };
        \\    }
        \\};
        \\
        \\export fn f() void {
        \\    const derp = Foo.init(3);
        \\
        \\    derp.init();
        \\}
    ,
        ".tmp_source.zig:14:5: error: expected type 'i32', found 'Foo'",
    );

    cases.add(
        "method call with first arg type wrong container",
        \\pub const List = struct {
        \\    len: usize,
        \\    allocator: *Allocator,
        \\
        \\    pub fn init(allocator: *Allocator) List {
        \\        return List {
        \\            .len = 0,
        \\            .allocator = allocator,
        \\        };
        \\    }
        \\};
        \\
        \\pub var global_allocator = Allocator {
        \\    .field = 1234,
        \\};
        \\
        \\pub const Allocator = struct {
        \\    field: i32,
        \\};
        \\
        \\export fn foo() void {
        \\    var x = List.init(&global_allocator);
        \\    x.init();
        \\}
    ,
        ".tmp_source.zig:23:5: error: expected type '*Allocator', found '*List'",
    );

    cases.add(
        "binary not on number literal",
        \\const TINY_QUANTUM_SHIFT = 4;
        \\const TINY_QUANTUM_SIZE = 1 << TINY_QUANTUM_SHIFT;
        \\var block_aligned_stuff: usize = (4 + TINY_QUANTUM_SIZE) & ~(TINY_QUANTUM_SIZE - 1);
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(block_aligned_stuff)); }
    ,
        ".tmp_source.zig:3:60: error: unable to perform binary not operation on type 'comptime_int'",
    );

    cases.addCase(x: {
        const tc = cases.create(
            "multiple files with private function error",
            \\const foo = @import("foo.zig",);
            \\
            \\export fn callPrivFunction() void {
            \\    foo.privateFunction();
            \\}
        ,
            ".tmp_source.zig:4:8: error: 'privateFunction' is private",
            "foo.zig:1:1: note: declared here",
        );

        tc.addSourceFile("foo.zig",
            \\fn privateFunction() void { }
        );

        break :x tc;
    });

    cases.add(
        "container init with non-type",
        \\const zero: i32 = 0;
        \\const a = zero{1};
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(a)); }
    ,
        ".tmp_source.zig:2:11: error: expected type, found 'i32'",
    );

    cases.add(
        "assign to constant field",
        \\const Foo = struct {
        \\    field: i32,
        \\};
        \\export fn derp() void {
        \\    const f = Foo {.field = 1234,};
        \\    f.field = 0;
        \\}
    ,
        ".tmp_source.zig:6:13: error: cannot assign to constant",
    );

    cases.add(
        "return from defer expression",
        \\pub fn testTrickyDefer() !void {
        \\    defer canFail() catch {};
        \\
        \\    defer try canFail();
        \\
        \\    const a = maybeInt() orelse return;
        \\}
        \\
        \\fn canFail() error!void { }
        \\
        \\pub fn maybeInt() ?i32 {
        \\    return 0;
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(testTrickyDefer)); }
    ,
        ".tmp_source.zig:4:11: error: cannot return from defer expression",
    );

    cases.add(
        "attempt to access var args out of bounds",
        \\fn add(args: ...) i32 {
        \\    return args[0] + args[1];
        \\}
        \\
        \\fn foo() i32 {
        \\    return add(i32(1234));
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:2:26: error: index 1 outside argument list of size 1",
        ".tmp_source.zig:6:15: note: called from here",
    );

    cases.add(
        "pass integer literal to var args",
        \\fn add(args: ...) i32 {
        \\    var sum = i32(0);
        \\    {comptime var i: usize = 0; inline while (i < args.len) : (i += 1) {
        \\        sum += args[i];
        \\    }}
        \\    return sum;
        \\}
        \\
        \\fn bar() i32 {
        \\    return add(1, 2, 3, 4);
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(bar)); }
    ,
        ".tmp_source.zig:10:16: error: compiler bug: integer and float literals in var args function must be casted",
    );

    cases.add(
        "assign too big number to u16",
        \\export fn foo() void {
        \\    var vga_mem: u16 = 0xB8000;
        \\}
    ,
        ".tmp_source.zig:2:24: error: integer value 753664 cannot be implicitly casted to type 'u16'",
    );

    cases.add(
        "global variable alignment non power of 2",
        \\const some_data: [100]u8 align(3) = undefined;
        \\export fn entry() usize { return @sizeOf(@typeOf(some_data)); }
    ,
        ".tmp_source.zig:1:32: error: alignment value 3 is not a power of 2",
    );

    cases.add(
        "function alignment non power of 2",
        \\extern fn foo() align(3) void;
        \\export fn entry() void { return foo(); }
    ,
        ".tmp_source.zig:1:23: error: alignment value 3 is not a power of 2",
    );

    cases.add(
        "compile log",
        \\export fn foo() void {
        \\    comptime bar(12, "hi",);
        \\}
        \\fn bar(a: i32, b: []const u8) void {
        \\    @compileLog("begin",);
        \\    @compileLog("a", a, "b", b);
        \\    @compileLog("end",);
        \\}
    ,
        ".tmp_source.zig:5:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here",
        ".tmp_source.zig:6:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here",
        ".tmp_source.zig:7:5: error: found compile log statement",
        ".tmp_source.zig:2:17: note: called from here",
    );

    cases.add(
        "casting bit offset pointer to regular pointer",
        \\const BitField = packed struct {
        \\    a: u3,
        \\    b: u3,
        \\    c: u2,
        \\};
        \\
        \\fn foo(bit_field: *const BitField) u3 {
        \\    return bar(&bit_field.b);
        \\}
        \\
        \\fn bar(x: *const u3) u3 {
        \\    return x.*;
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:8:26: error: expected type '*const u3', found '*align(1:3:6) const u3'",
    );

    cases.add(
        "referring to a struct that is invalid",
        \\const UsbDeviceRequest = struct {
        \\    Type: u8,
        \\};
        \\
        \\export fn foo() void {
        \\    comptime assert(@sizeOf(UsbDeviceRequest) == 0x8);
        \\}
        \\
        \\fn assert(ok: bool) void {
        \\    if (!ok) unreachable;
        \\}
    ,
        ".tmp_source.zig:10:14: error: unable to evaluate constant expression",
        ".tmp_source.zig:6:20: note: called from here",
    );

    cases.add(
        "control flow uses comptime var at runtime",
        \\export fn foo() void {
        \\    comptime var i = 0;
        \\    while (i < 5) : (i += 1) {
        \\        bar();
        \\    }
        \\}
        \\
        \\fn bar() void { }
    ,
        ".tmp_source.zig:3:5: error: control flow attempts to use compile-time variable at runtime",
        ".tmp_source.zig:3:24: note: compile-time variable assigned here",
    );

    cases.add(
        "ignored return value",
        \\export fn foo() void {
        \\    bar();
        \\}
        \\fn bar() i32 { return 0; }
    ,
        ".tmp_source.zig:2:8: error: expression value is ignored",
    );

    cases.add(
        "ignored assert-err-ok return value",
        \\export fn foo() void {
        \\    bar() catch unreachable;
        \\}
        \\fn bar() error!i32 { return 0; }
    ,
        ".tmp_source.zig:2:11: error: expression value is ignored",
    );

    cases.add(
        "ignored statement value",
        \\export fn foo() void {
        \\    1;
        \\}
    ,
        ".tmp_source.zig:2:5: error: expression value is ignored",
    );

    cases.add(
        "ignored comptime statement value",
        \\export fn foo() void {
        \\    comptime {1;}
        \\}
    ,
        ".tmp_source.zig:2:15: error: expression value is ignored",
    );

    cases.add(
        "ignored comptime value",
        \\export fn foo() void {
        \\    comptime 1;
        \\}
    ,
        ".tmp_source.zig:2:5: error: expression value is ignored",
    );

    cases.add(
        "ignored defered statement value",
        \\export fn foo() void {
        \\    defer {1;}
        \\}
    ,
        ".tmp_source.zig:2:12: error: expression value is ignored",
    );

    cases.add(
        "ignored defered function call",
        \\export fn foo() void {
        \\    defer bar();
        \\}
        \\fn bar() error!i32 { return 0; }
    ,
        ".tmp_source.zig:2:14: error: expression value is ignored",
    );

    cases.add(
        "dereference an array",
        \\var s_buffer: [10]u8 = undefined;
        \\pub fn pass(in: []u8) []u8 {
        \\    var out = &s_buffer;
        \\    out.*.* = in[0];
        \\    return out.*[0..1];
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(pass)); }
    ,
        ".tmp_source.zig:4:10: error: attempt to dereference non pointer type '[10]u8'",
    );

    cases.add(
        "pass const ptr to mutable ptr fn",
        \\fn foo() bool {
        \\    const a = ([]const u8)("a",);
        \\    const b = &a;
        \\    return ptrEql(b, b);
        \\}
        \\fn ptrEql(a: *[]const u8, b: *[]const u8) bool {
        \\    return true;
        \\}
        \\
        \\export fn entry() usize { return @sizeOf(@typeOf(foo)); }
    ,
        ".tmp_source.zig:4:19: error: expected type '*[]const u8', found '*const []const u8'",
    );

    cases.addCase(x: {
        const tc = cases.create(
            "export collision",
            \\const foo = @import("foo.zig",);
            \\
            \\export fn bar() usize {
            \\    return foo.baz;
            \\}
        ,
            "foo.zig:1:8: error: exported symbol collision: 'bar'",
            ".tmp_source.zig:3:8: note: other symbol here",
        );

        tc.addSourceFile("foo.zig",
            \\export fn bar() void {}
            \\pub const baz = 1234;
        );

        break :x tc;
    });

    cases.add(
        "implicit cast from array to mutable slice",
        \\var global_array: [10]i32 = undefined;
        \\fn foo(param: []i32) void {}
        \\export fn entry() void {
        \\    foo(global_array);
        \\}
    ,
        ".tmp_source.zig:4:9: error: expected type '[]i32', found '[10]i32'",
    );

    cases.add(
        "ptrcast to non-pointer",
        \\export fn entry(a: *i32) usize {
        \\    return @ptrCast(usize, a);
        \\}
    ,
        ".tmp_source.zig:2:21: error: expected pointer, found 'usize'",
    );

    cases.add(
        "asm at compile time",
        \\comptime {
        \\    doSomeAsm();
        \\}
        \\
        \\fn doSomeAsm() void {
        \\    asm volatile (
        \\        \\.globl aoeu;
        \\        \\.type aoeu, @function;
        \\        \\.set aoeu, derp;
        \\    );
        \\}
    ,
        ".tmp_source.zig:6:5: error: unable to evaluate constant expression",
    );

    cases.add(
        "invalid member of builtin enum",
        \\const builtin = @import("builtin",);
        \\export fn entry() void {
        \\    const foo = builtin.Arch.x86;
        \\}
    ,
        ".tmp_source.zig:3:29: error: container 'Arch' has no member called 'x86'",
    );

    cases.add(
        "int to ptr of 0 bits",
        \\export fn foo() void {
        \\    var x: usize = 0x1000;
        \\    var y: *void = @intToPtr(*void, x);
        \\}
    ,
        ".tmp_source.zig:3:30: error: type '*void' has 0 bits and cannot store information",
    );

    cases.add(
        "@fieldParentPtr - non struct",
        \\const Foo = i32;
        \\export fn foo(a: *i32) *Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
    ,
        ".tmp_source.zig:3:28: error: expected struct type, found 'i32'",
    );

    cases.add(
        "@fieldParentPtr - bad field name",
        \\const Foo = extern struct {
        \\    derp: i32,
        \\};
        \\export fn foo(a: *i32) *Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
    ,
        ".tmp_source.zig:5:33: error: struct 'Foo' has no field 'a'",
    );

    cases.add(
        "@fieldParentPtr - field pointer is not pointer",
        \\const Foo = extern struct {
        \\    a: i32,
        \\};
        \\export fn foo(a: i32) *Foo {
        \\    return @fieldParentPtr(Foo, "a", a);
        \\}
    ,
        ".tmp_source.zig:5:38: error: expected pointer, found 'i32'",
    );

    cases.add(
        "@fieldParentPtr - comptime field ptr not based on struct",
        \\const Foo = struct {
        \\    a: i32,
        \\    b: i32,
        \\};
        \\const foo = Foo { .a = 1, .b = 2, };
        \\
        \\comptime {
        \\    const field_ptr = @intToPtr(*i32, 0x1234);
        \\    const another_foo_ptr = @fieldParentPtr(Foo, "b", field_ptr);
        \\}
    ,
        ".tmp_source.zig:9:55: error: pointer value not based on parent struct",
    );

    cases.add(
        "@fieldParentPtr - comptime wrong field index",
        \\const Foo = struct {
        \\    a: i32,
        \\    b: i32,
        \\};
        \\const foo = Foo { .a = 1, .b = 2, };
        \\
        \\comptime {
        \\    const another_foo_ptr = @fieldParentPtr(Foo, "b", &foo.a);
        \\}
    ,
        ".tmp_source.zig:8:29: error: field 'b' has index 1 but pointer value is index 0 of struct 'Foo'",
    );

    cases.add(
        "@offsetOf - non struct",
        \\const Foo = i32;
        \\export fn foo() usize {
        \\    return @offsetOf(Foo, "a",);
        \\}
    ,
        ".tmp_source.zig:3:22: error: expected struct type, found 'i32'",
    );

    cases.add(
        "@offsetOf - bad field name",
        \\const Foo = struct {
        \\    derp: i32,
        \\};
        \\export fn foo() usize {
        \\    return @offsetOf(Foo, "a",);
        \\}
    ,
        ".tmp_source.zig:5:27: error: struct 'Foo' has no field 'a'",
    );

    cases.addExe(
        "missing main fn in executable",
        \\
    ,
        "error: no member named 'main' in '",
    );

    cases.addExe(
        "private main fn",
        \\fn main() void {}
    ,
        "error: 'main' is private",
        ".tmp_source.zig:1:1: note: declared here",
    );

    cases.add(
        "setting a section on an extern variable",
        \\extern var foo: i32 section(".text2");
        \\export fn entry() i32 {
        \\    return foo;
        \\}
    ,
        ".tmp_source.zig:1:29: error: cannot set section of external variable 'foo'",
    );

    cases.add(
        "setting a section on a local variable",
        \\export fn entry() i32 {
        \\    var foo: i32 section(".text2") = 1234;
        \\    return foo;
        \\}
    ,
        ".tmp_source.zig:2:26: error: cannot set section of local variable 'foo'",
    );

    cases.add(
        "setting a section on an extern fn",
        \\extern fn foo() section(".text2") void;
        \\export fn entry() void {
        \\    foo();
        \\}
    ,
        ".tmp_source.zig:1:25: error: cannot set section of external function 'foo'",
    );

    cases.add(
        "returning address of local variable - simple",
        \\export fn foo() *i32 {
        \\    var a: i32 = undefined;
        \\    return &a;
        \\}
    ,
        ".tmp_source.zig:3:13: error: function returns address of local variable",
    );

    cases.add(
        "returning address of local variable - phi",
        \\export fn foo(c: bool) *i32 {
        \\    var a: i32 = undefined;
        \\    var b: i32 = undefined;
        \\    return if (c) &a else &b;
        \\}
    ,
        ".tmp_source.zig:4:12: error: function returns address of local variable",
    );

    cases.add(
        "inner struct member shadowing outer struct member",
        \\fn A() type {
        \\    return struct {
        \\        b: B(),
        \\
        \\        const Self = this;
        \\
        \\        fn B() type {
        \\            return struct {
        \\                const Self = this;
        \\            };
        \\        }
        \\    };
        \\}
        \\comptime {
        \\    assert(A().B().Self != A().Self);
        \\}
        \\fn assert(ok: bool) void {
        \\    if (!ok) unreachable;
        \\}
    ,
        ".tmp_source.zig:9:17: error: redefinition of 'Self'",
        ".tmp_source.zig:5:9: note: previous definition is here",
    );

    cases.add(
        "while expected bool, got optional",
        \\export fn foo() void {
        \\    while (bar()) {}
        \\}
        \\fn bar() ?i32 { return 1; }
    ,
        ".tmp_source.zig:2:15: error: expected type 'bool', found '?i32'",
    );

    cases.add(
        "while expected bool, got error union",
        \\export fn foo() void {
        \\    while (bar()) {}
        \\}
        \\fn bar() error!i32 { return 1; }
    ,
        ".tmp_source.zig:2:15: error: expected type 'bool', found 'error!i32'",
    );

    cases.add(
        "while expected optional, got bool",
        \\export fn foo() void {
        \\    while (bar()) |x| {}
        \\}
        \\fn bar() bool { return true; }
    ,
        ".tmp_source.zig:2:15: error: expected optional type, found 'bool'",
    );

    cases.add(
        "while expected optional, got error union",
        \\export fn foo() void {
        \\    while (bar()) |x| {}
        \\}
        \\fn bar() error!i32 { return 1; }
    ,
        ".tmp_source.zig:2:15: error: expected optional type, found 'error!i32'",
    );

    cases.add(
        "while expected error union, got bool",
        \\export fn foo() void {
        \\    while (bar()) |x| {} else |err| {}
        \\}
        \\fn bar() bool { return true; }
    ,
        ".tmp_source.zig:2:15: error: expected error union type, found 'bool'",
    );

    cases.add(
        "while expected error union, got optional",
        \\export fn foo() void {
        \\    while (bar()) |x| {} else |err| {}
        \\}
        \\fn bar() ?i32 { return 1; }
    ,
        ".tmp_source.zig:2:15: error: expected error union type, found '?i32'",
    );

    cases.add(
        "inline fn calls itself indirectly",
        \\export fn foo() void {
        \\    bar();
        \\}
        \\inline fn bar() void {
        \\    baz();
        \\    quux();
        \\}
        \\inline fn baz() void {
        \\    bar();
        \\    quux();
        \\}
        \\extern fn quux() void;
    ,
        ".tmp_source.zig:4:8: error: unable to inline function",
    );

    cases.add(
        "save reference to inline function",
        \\export fn foo() void {
        \\    quux(@ptrToInt(bar));
        \\}
        \\inline fn bar() void { }
        \\extern fn quux(usize) void;
    ,
        ".tmp_source.zig:4:8: error: unable to inline function",
    );

    cases.add(
        "signed integer division",
        \\export fn foo(a: i32, b: i32) i32 {
        \\    return a / b;
        \\}
    ,
        ".tmp_source.zig:2:14: error: division with 'i32' and 'i32': signed integers must use @divTrunc, @divFloor, or @divExact",
    );

    cases.add(
        "signed integer remainder division",
        \\export fn foo(a: i32, b: i32) i32 {
        \\    return a % b;
        \\}
    ,
        ".tmp_source.zig:2:14: error: remainder division with 'i32' and 'i32': signed integers and floats must use @rem or @mod",
    );

    cases.add(
        "cast negative value to unsigned integer",
        \\comptime {
        \\    const value: i32 = -1;
        \\    const unsigned = @intCast(u32, value);
        \\}
    ,
        ".tmp_source.zig:3:22: error: attempt to cast negative value to unsigned integer",
    );

    cases.add(
        "compile-time division by zero",
        \\comptime {
        \\    const a: i32 = 1;
        \\    const b: i32 = 0;
        \\    const c = a / b;
        \\}
    ,
        ".tmp_source.zig:4:17: error: division by zero",
    );

    cases.add(
        "compile-time remainder division by zero",
        \\comptime {
        \\    const a: i32 = 1;
        \\    const b: i32 = 0;
        \\    const c = a % b;
        \\}
    ,
        ".tmp_source.zig:4:17: error: division by zero",
    );

    cases.add(
        "compile-time integer cast truncates bits",
        \\comptime {
        \\    const spartan_count: u16 = 300;
        \\    const byte = @intCast(u8, spartan_count);
        \\}
    ,
        ".tmp_source.zig:3:18: error: cast from 'u16' to 'u8' truncates bits",
    );

    cases.add(
        "@setRuntimeSafety twice for same scope",
        \\export fn foo() void {
        \\    @setRuntimeSafety(false);
        \\    @setRuntimeSafety(false);
        \\}
    ,
        ".tmp_source.zig:3:5: error: runtime safety set twice for same scope",
        ".tmp_source.zig:2:5: note: first set here",
    );

    cases.add(
        "@setFloatMode twice for same scope",
        \\export fn foo() void {
        \\    @setFloatMode(this, @import("builtin").FloatMode.Optimized);
        \\    @setFloatMode(this, @import("builtin").FloatMode.Optimized);
        \\}
    ,
        ".tmp_source.zig:3:5: error: float mode set twice for same scope",
        ".tmp_source.zig:2:5: note: first set here",
    );

    cases.add(
        "array access of type",
        \\export fn foo() void {
        \\    var b: u8[40] = undefined;
        \\}
    ,
        ".tmp_source.zig:2:14: error: array access of non-array type 'type'",
    );

    cases.add(
        "cannot break out of defer expression",
        \\export fn foo() void {
        \\    while (true) {
        \\        defer {
        \\            break;
        \\        }
        \\    }
        \\}
    ,
        ".tmp_source.zig:4:13: error: cannot break out of defer expression",
    );

    cases.add(
        "cannot continue out of defer expression",
        \\export fn foo() void {
        \\    while (true) {
        \\        defer {
        \\            continue;
        \\        }
        \\    }
        \\}
    ,
        ".tmp_source.zig:4:13: error: cannot continue out of defer expression",
    );

    cases.add(
        "calling a var args function only known at runtime",
        \\var foos = []fn(...) void { foo1, foo2 };
        \\
        \\fn foo1(args: ...) void {}
        \\fn foo2(args: ...) void {}
        \\
        \\pub fn main() !void {
        \\    foos[0]();
        \\}
    ,
        ".tmp_source.zig:7:9: error: calling a generic function requires compile-time known function value",
    );

    cases.add(
        "calling a generic function only known at runtime",
        \\var foos = []fn(var) void { foo1, foo2 };
        \\
        \\fn foo1(arg: var) void {}
        \\fn foo2(arg: var) void {}
        \\
        \\pub fn main() !void {
        \\    foos[0](true);
        \\}
    ,
        ".tmp_source.zig:7:9: error: calling a generic function requires compile-time known function value",
    );

    cases.add(
        "@compileError shows traceback of references that caused it",
        \\const foo = @compileError("aoeu",);
        \\
        \\const bar = baz + foo;
        \\const baz = 1;
        \\
        \\export fn entry() i32 {
        \\    return bar;
        \\}
    ,
        ".tmp_source.zig:1:13: error: aoeu",
        ".tmp_source.zig:3:19: note: referenced here",
        ".tmp_source.zig:7:12: note: referenced here",
    );

    cases.add(
        "instantiating an undefined value for an invalid struct that contains itself",
        \\const Foo = struct {
        \\    x: Foo,
        \\};
        \\
        \\var foo: Foo = undefined;
        \\
        \\export fn entry() usize {
        \\    return @sizeOf(@typeOf(foo.x));
        \\}
    ,
        ".tmp_source.zig:1:13: error: struct 'Foo' contains itself",
    );

    cases.add(
        "float literal too large error",
        \\comptime {
        \\    const a = 0x1.0p16384;
        \\}
    ,
        ".tmp_source.zig:2:15: error: float literal out of range of any type",
    );

    cases.add(
        "float literal too small error (denormal)",
        \\comptime {
        \\    const a = 0x1.0p-16384;
        \\}
    ,
        ".tmp_source.zig:2:15: error: float literal out of range of any type",
    );

    cases.add(
        "explicit cast float literal to integer when there is a fraction component",
        \\export fn entry() i32 {
        \\    return i32(12.34);
        \\}
    ,
        ".tmp_source.zig:2:16: error: fractional component prevents float value 12.340000 from being casted to type 'i32'",
    );

    cases.add(
        "non pointer given to @ptrToInt",
        \\export fn entry(x: i32) usize {
        \\    return @ptrToInt(x);
        \\}
    ,
        ".tmp_source.zig:2:22: error: expected pointer, found 'i32'",
    );

    cases.add(
        "@shlExact shifts out 1 bits",
        \\comptime {
        \\    const x = @shlExact(u8(0b01010101), 2);
        \\}
    ,
        ".tmp_source.zig:2:15: error: operation caused overflow",
    );

    cases.add(
        "@shrExact shifts out 1 bits",
        \\comptime {
        \\    const x = @shrExact(u8(0b10101010), 2);
        \\}
    ,
        ".tmp_source.zig:2:15: error: exact shift shifted out 1 bits",
    );

    cases.add(
        "shifting without int type or comptime known",
        \\export fn entry(x: u8) u8 {
        \\    return 0x11 << x;
        \\}
    ,
        ".tmp_source.zig:2:17: error: LHS of shift must be an integer type, or RHS must be compile-time known",
    );

    cases.add(
        "shifting RHS is log2 of LHS int bit width",
        \\export fn entry(x: u8, y: u8) u8 {
        \\    return x << y;
        \\}
    ,
        ".tmp_source.zig:2:17: error: expected type 'u3', found 'u8'",
    );

    cases.add(
        "globally shadowing a primitive type",
        \\const u16 = @intType(false, 8);
        \\export fn entry() void {
        \\    const a: u16 = 300;
        \\}
    ,
        ".tmp_source.zig:1:1: error: declaration shadows type 'u16'",
    );

    cases.add(
        "implicitly increasing pointer alignment",
        \\const Foo = packed struct {
        \\    a: u8,
        \\    b: u32,
        \\};
        \\
        \\export fn entry() void {
        \\    var foo = Foo { .a = 1, .b = 10 };
        \\    bar(&foo.b);
        \\}
        \\
        \\fn bar(x: *u32) void {
        \\    x.* += 1;
        \\}
    ,
        ".tmp_source.zig:8:13: error: expected type '*u32', found '*align(1) u32'",
    );

    cases.add(
        "implicitly increasing slice alignment",
        \\const Foo = packed struct {
        \\    a: u8,
        \\    b: u32,
        \\};
        \\
        \\export fn entry() void {
        \\    var foo = Foo { .a = 1, .b = 10 };
        \\    foo.b += 1;
        \\    bar((*[1]u32)(&foo.b)[0..]);
        \\}
        \\
        \\fn bar(x: []u32) void {
        \\    x[0] += 1;
        \\}
    ,
        ".tmp_source.zig:9:18: error: cast increases pointer alignment",
        ".tmp_source.zig:9:23: note: '*align(1) u32' has alignment 1",
        ".tmp_source.zig:9:18: note: '*[1]u32' has alignment 4",
    );

    cases.add(
        "increase pointer alignment in @ptrCast",
        \\export fn entry() u32 {
        \\    var bytes: [4]u8 = []u8{0x01, 0x02, 0x03, 0x04};
        \\    const ptr = @ptrCast(*u32, &bytes[0]);
        \\    return ptr.*;
        \\}
    ,
        ".tmp_source.zig:3:17: error: cast increases pointer alignment",
        ".tmp_source.zig:3:38: note: '*u8' has alignment 1",
        ".tmp_source.zig:3:26: note: '*u32' has alignment 4",
    );

    cases.add(
        "@alignCast expects pointer or slice",
        \\export fn entry() void {
        \\    @alignCast(4, u32(3));
        \\}
    ,
        ".tmp_source.zig:2:22: error: expected pointer or slice, found 'u32'",
    );

    cases.add(
        "passing an under-aligned function pointer",
        \\export fn entry() void {
        \\    testImplicitlyDecreaseFnAlign(alignedSmall, 1234);
        \\}
        \\fn testImplicitlyDecreaseFnAlign(ptr: fn () align(8) i32, answer: i32) void {
        \\    if (ptr() != answer) unreachable;
        \\}
        \\fn alignedSmall() align(4) i32 { return 1234; }
    ,
        ".tmp_source.zig:2:35: error: expected type 'fn() align(8) i32', found 'fn() align(4) i32'",
    );

    cases.add(
        "passing a not-aligned-enough pointer to cmpxchg",
        \\const AtomicOrder = @import("builtin").AtomicOrder;
        \\export fn entry() bool {
        \\    var x: i32 align(1) = 1234;
        \\    while (!@cmpxchgWeak(i32, &x, 1234, 5678, AtomicOrder.SeqCst, AtomicOrder.SeqCst)) {}
        \\    return x == 5678;
        \\}
    ,
        ".tmp_source.zig:4:32: error: expected type '*i32', found '*align(1) i32'",
    );

    cases.add(
        "wrong size to an array literal",
        \\comptime {
        \\    const array = [2]u8{1, 2, 3};
        \\}
    ,
        ".tmp_source.zig:2:24: error: expected [2]u8 literal, found [3]u8 literal",
    );

    cases.add(
        "@setEvalBranchQuota in non-root comptime execution context",
        \\comptime {
        \\    foo();
        \\}
        \\fn foo() void {
        \\    @setEvalBranchQuota(1001);
        \\}
    ,
        ".tmp_source.zig:5:5: error: @setEvalBranchQuota must be called from the top of the comptime stack",
        ".tmp_source.zig:2:8: note: called from here",
        ".tmp_source.zig:1:10: note: called from here",
    );

    cases.add(
        "wrong pointer implicitly casted to pointer to @OpaqueType()",
        \\const Derp = @OpaqueType();
        \\extern fn bar(d: *Derp) void;
        \\export fn foo() void {
        \\    var x = u8(1);
        \\    bar(@ptrCast(*c_void, &x));
        \\}
    ,
        ".tmp_source.zig:5:9: error: expected type '*Derp', found '*c_void'",
    );

    cases.add(
        "non-const variables of things that require const variables",
        \\const Opaque = @OpaqueType();
        \\
        \\export fn entry(opaque: *Opaque) void {
        \\   var m2 = &2;
        \\   const y: u32 = m2.*;
        \\
        \\   var a = undefined;
        \\   var b = 1;
        \\   var c = 1.0;
        \\   var d = this;
        \\   var e = null;
        \\   var f = opaque.*;
        \\   var g = i32;
        \\   var h = @import("std",);
        \\   var i = (Foo {}).bar;
        \\
        \\   var z: noreturn = return;
        \\}
        \\
        \\const Foo = struct {
        \\    fn bar(self: *const Foo) void {}
        \\};
    ,
        ".tmp_source.zig:4:4: error: variable of type '*comptime_int' must be const or comptime",
        ".tmp_source.zig:7:4: error: variable of type '(undefined)' must be const or comptime",
        ".tmp_source.zig:8:4: error: variable of type 'comptime_int' must be const or comptime",
        ".tmp_source.zig:9:4: error: variable of type 'comptime_float' must be const or comptime",
        ".tmp_source.zig:10:4: error: variable of type '(block)' must be const or comptime",
        ".tmp_source.zig:11:4: error: variable of type '(null)' must be const or comptime",
        ".tmp_source.zig:12:4: error: variable of type 'Opaque' not allowed",
        ".tmp_source.zig:13:4: error: variable of type 'type' must be const or comptime",
        ".tmp_source.zig:14:4: error: variable of type '(namespace)' must be const or comptime",
        ".tmp_source.zig:15:4: error: variable of type '(bound fn(*const Foo) void)' must be const or comptime",
        ".tmp_source.zig:17:4: error: unreachable code",
    );

    cases.add(
        "wrong types given to atomic order args in cmpxchg",
        \\export fn entry() void {
        \\    var x: i32 = 1234;
        \\    while (!@cmpxchgWeak(i32, &x, 1234, 5678, u32(1234), u32(1234))) {}
        \\}
    ,
        ".tmp_source.zig:3:50: error: expected type 'AtomicOrder', found 'u32'",
    );

    cases.add(
        "wrong types given to @export",
        \\extern fn entry() void { }
        \\comptime {
        \\    @export("entry", entry, u32(1234));
        \\}
    ,
        ".tmp_source.zig:3:32: error: expected type 'GlobalLinkage', found 'u32'",
    );

    cases.add(
        "struct with invalid field",
        \\const std = @import("std",);
        \\const Allocator = std.mem.Allocator;
        \\const ArrayList = std.ArrayList;
        \\
        \\const HeaderWeight = enum {
        \\    H1, H2, H3, H4, H5, H6,
        \\};
        \\
        \\const MdText = ArrayList(u8);
        \\
        \\const MdNode = union(enum) {
        \\    Header: struct {
        \\        text: MdText,
        \\        weight: HeaderValue,
        \\    },
        \\};
        \\
        \\export fn entry() void {
        \\    const a = MdNode.Header {
        \\        .text = MdText.init(&std.debug.global_allocator),
        \\        .weight = HeaderWeight.H1,
        \\    };
        \\}
    ,
        ".tmp_source.zig:14:17: error: use of undeclared identifier 'HeaderValue'",
    );

    cases.add(
        "@setAlignStack outside function",
        \\comptime {
        \\    @setAlignStack(16);
        \\}
    ,
        ".tmp_source.zig:2:5: error: @setAlignStack outside function",
    );

    cases.add(
        "@setAlignStack in naked function",
        \\export nakedcc fn entry() void {
        \\    @setAlignStack(16);
        \\}
    ,
        ".tmp_source.zig:2:5: error: @setAlignStack in naked function",
    );

    cases.add(
        "@setAlignStack in inline function",
        \\export fn entry() void {
        \\    foo();
        \\}
        \\inline fn foo() void {
        \\    @setAlignStack(16);
        \\}
    ,
        ".tmp_source.zig:5:5: error: @setAlignStack in inline function",
    );

    cases.add(
        "@setAlignStack set twice",
        \\export fn entry() void {
        \\    @setAlignStack(16);
        \\    @setAlignStack(16);
        \\}
    ,
        ".tmp_source.zig:3:5: error: alignstack set twice",
        ".tmp_source.zig:2:5: note: first set here",
    );

    cases.add(
        "@setAlignStack too big",
        \\export fn entry() void {
        \\    @setAlignStack(511 + 1);
        \\}
    ,
        ".tmp_source.zig:2:5: error: attempt to @setAlignStack(512); maximum is 256",
    );

    cases.add(
        "storing runtime value in compile time variable then using it",
        \\const Mode = @import("builtin").Mode;
        \\
        \\fn Free(comptime filename: []const u8) TestCase {
        \\    return TestCase {
        \\        .filename = filename,
        \\        .problem_type = ProblemType.Free,
        \\    };
        \\}
        \\
        \\fn LibC(comptime filename: []const u8) TestCase {
        \\    return TestCase {
        \\        .filename = filename,
        \\        .problem_type = ProblemType.LinkLibC,
        \\    };
        \\}
        \\
        \\const TestCase = struct {
        \\    filename: []const u8,
        \\    problem_type: ProblemType,
        \\};
        \\
        \\const ProblemType = enum {
        \\    Free,
        \\    LinkLibC,
        \\};
        \\
        \\export fn entry() void {
        \\    const tests = []TestCase {
        \\        Free("001"),
        \\        Free("002"),
        \\        LibC("078"),
        \\        Free("116"),
        \\        Free("117"),
        \\    };
        \\
        \\    for ([]Mode { Mode.Debug, Mode.ReleaseSafe, Mode.ReleaseFast }) |mode| {
        \\        inline for (tests) |test_case| {
        \\            const foo = test_case.filename ++ ".zig";
        \\        }
        \\    }
        \\}
    ,
        ".tmp_source.zig:37:16: error: cannot store runtime value in compile time variable",
    );

    cases.add(
        "field access of opaque type",
        \\const MyType = @OpaqueType();
        \\
        \\export fn entry() bool {
        \\    var x: i32 = 1;
        \\    return bar(@ptrCast(*MyType, &x));
        \\}
        \\
        \\fn bar(x: *MyType) bool {
        \\    return x.blah;
        \\}
    ,
        ".tmp_source.zig:9:13: error: type '*MyType' does not support field access",
    );

    cases.add(
        "carriage return special case",
        "fn test() bool {\r\n" ++
            "   true\r\n" ++
            "}\r\n",
        ".tmp_source.zig:1:17: error: invalid carriage return, only '\\n' line endings are supported",
    );

    cases.add(
        "non-printable invalid character",
        "\xff\xfe" ++            
            \\fn test() bool {\r
            \\    true\r
            \\}
        ,
        ".tmp_source.zig:1:1: error: invalid character: '\\xff'",
    );

    cases.add(
        "non-printable invalid character with escape alternative",
        "fn test() bool {\n" ++
            "\ttrue\n" ++
            "}\n",
        ".tmp_source.zig:2:1: error: invalid character: '\\t'",
    );

    cases.add(
        "@ArgType given non function parameter",
        \\comptime {
        \\    _ = @ArgType(i32, 3);
        \\}
    ,
        ".tmp_source.zig:2:18: error: expected function, found 'i32'",
    );

    cases.add(
        "@ArgType arg index out of bounds",
        \\comptime {
        \\    _ = @ArgType(@typeOf(add), 2);
        \\}
        \\fn add(a: i32, b: i32) i32 { return a + b; }
    ,
        ".tmp_source.zig:2:32: error: arg index 2 out of bounds; 'fn(i32, i32) i32' has 2 arguments",
    );

    cases.add(
        "@memberType on unsupported type",
        \\comptime {
        \\    _ = @memberType(i32, 0);
        \\}
    ,
        ".tmp_source.zig:2:21: error: type 'i32' does not support @memberType",
    );

    cases.add(
        "@memberType on enum",
        \\comptime {
        \\    _ = @memberType(Foo, 0);
        \\}
        \\const Foo = enum {A,};
    ,
        ".tmp_source.zig:2:21: error: type 'Foo' does not support @memberType",
    );

    cases.add(
        "@memberType struct out of bounds",
        \\comptime {
        \\    _ = @memberType(Foo, 0);
        \\}
        \\const Foo = struct {};
    ,
        ".tmp_source.zig:2:26: error: member index 0 out of bounds; 'Foo' has 0 members",
    );

    cases.add(
        "@memberType union out of bounds",
        \\comptime {
        \\    _ = @memberType(Foo, 1);
        \\}
        \\const Foo = union {A: void,};
    ,
        ".tmp_source.zig:2:26: error: member index 1 out of bounds; 'Foo' has 1 members",
    );

    cases.add(
        "@memberName on unsupported type",
        \\comptime {
        \\    _ = @memberName(i32, 0);
        \\}
    ,
        ".tmp_source.zig:2:21: error: type 'i32' does not support @memberName",
    );

    cases.add(
        "@memberName struct out of bounds",
        \\comptime {
        \\    _ = @memberName(Foo, 0);
        \\}
        \\const Foo = struct {};
    ,
        ".tmp_source.zig:2:26: error: member index 0 out of bounds; 'Foo' has 0 members",
    );

    cases.add(
        "@memberName enum out of bounds",
        \\comptime {
        \\    _ = @memberName(Foo, 1);
        \\}
        \\const Foo = enum {A,};
    ,
        ".tmp_source.zig:2:26: error: member index 1 out of bounds; 'Foo' has 1 members",
    );

    cases.add(
        "@memberName union out of bounds",
        \\comptime {
        \\    _ = @memberName(Foo, 1);
        \\}
        \\const Foo = union {A:i32,};
    ,
        ".tmp_source.zig:2:26: error: member index 1 out of bounds; 'Foo' has 1 members",
    );

    cases.add(
        "calling var args extern function, passing array instead of pointer",
        \\export fn entry() void {
        \\    foo("hello",);
        \\}
        \\pub extern fn foo(format: *const u8, ...) void;
    ,
        ".tmp_source.zig:2:9: error: expected type '*const u8', found '[5]u8'",
    );

    cases.add(
        "constant inside comptime function has compile error",
        \\const ContextAllocator = MemoryPool(usize);
        \\
        \\pub fn MemoryPool(comptime T: type) type {
        \\    const free_list_t = @compileError("aoeu",);
        \\
        \\    return struct {
        \\        free_list: free_list_t,
        \\    };
        \\}
        \\
        \\export fn entry() void {
        \\    var allocator: ContextAllocator = undefined;
        \\}
    ,
        ".tmp_source.zig:4:25: error: aoeu",
        ".tmp_source.zig:1:36: note: called from here",
        ".tmp_source.zig:12:20: note: referenced here",
    );

    cases.add(
        "specify enum tag type that is too small",
        \\const Small = enum (u2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\    Five,
        \\};
        \\
        \\export fn entry() void {
        \\    var x = Small.One;
        \\}
    ,
        ".tmp_source.zig:1:20: error: 'u2' too small to hold all bits; must be at least 'u3'",
    );

    cases.add(
        "specify non-integer enum tag type",
        \\const Small = enum (f32) {
        \\    One,
        \\    Two,
        \\    Three,
        \\};
        \\
        \\export fn entry() void {
        \\    var x = Small.One;
        \\}
    ,
        ".tmp_source.zig:1:20: error: expected integer, found 'f32'",
    );

    cases.add(
        "implicitly casting enum to tag type",
        \\const Small = enum(u2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\
        \\export fn entry() void {
        \\    var x: u2 = Small.Two;
        \\}
    ,
        ".tmp_source.zig:9:22: error: expected type 'u2', found 'Small'",
    );

    cases.add(
        "explicitly casting non tag type to enum",
        \\const Small = enum(u2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\
        \\export fn entry() void {
        \\    var y = u3(3);
        \\    var x = @intToEnum(Small, y);
        \\}
    ,
        ".tmp_source.zig:10:31: error: expected type 'u2', found 'u3'",
    );

    cases.add(
        "non unsigned integer enum tag type",
        \\const Small = enum(i2) {
        \\    One,
        \\    Two,
        \\    Three,
        \\    Four,
        \\};
        \\
        \\export fn entry() void {
        \\    var y = Small.Two;
        \\}
    ,
        ".tmp_source.zig:1:19: error: expected unsigned integer, found 'i2'",
    );

    cases.add(
        "struct fields with value assignments",
        \\const MultipleChoice = struct {
        \\    A: i32 = 20,
        \\};
        \\export fn entry() void {
        \\        var x: MultipleChoice = undefined;
        \\}
    ,
        ".tmp_source.zig:2:14: error: enums, not structs, support field assignment",
    );

    cases.add(
        "union fields with value assignments",
        \\const MultipleChoice = union {
        \\    A: i32 = 20,
        \\};
        \\export fn entry() void {
        \\    var x: MultipleChoice = undefined;
        \\}
    ,
        ".tmp_source.zig:2:14: error: non-enum union field assignment",
        ".tmp_source.zig:1:24: note: consider 'union(enum)' here",
    );

    cases.add(
        "enum with 0 fields",
        \\const Foo = enum {};
        \\export fn entry() usize {
        \\    return @sizeOf(Foo);
        \\}
    ,
        ".tmp_source.zig:1:13: error: enums must have 1 or more fields",
    );

    cases.add(
        "union with 0 fields",
        \\const Foo = union {};
        \\export fn entry() usize {
        \\    return @sizeOf(Foo);
        \\}
    ,
        ".tmp_source.zig:1:13: error: unions must have 1 or more fields",
    );

    cases.add(
        "enum value already taken",
        \\const MultipleChoice = enum(u32) {
        \\    A = 20,
        \\    B = 40,
        \\    C = 60,
        \\    D = 1000,
        \\    E = 60,
        \\};
        \\export fn entry() void {
        \\    var x = MultipleChoice.C;
        \\}
    ,
        ".tmp_source.zig:6:9: error: enum tag value 60 already taken",
        ".tmp_source.zig:4:9: note: other occurrence here",
    );

    cases.add(
        "union with specified enum omits field",
        \\const Letter = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\const Payload = union(Letter) {
        \\    A: i32,
        \\    B: f64,
        \\};
        \\export fn entry() usize {
        \\    return @sizeOf(Payload);
        \\}
    ,
        ".tmp_source.zig:6:17: error: enum field missing: 'C'",
        ".tmp_source.zig:4:5: note: declared here",
    );

    cases.add(
        "@TagType when union has no attached enum",
        \\const Foo = union {
        \\    A: i32,
        \\};
        \\export fn entry() void {
        \\    const x = @TagType(Foo);
        \\}
    ,
        ".tmp_source.zig:5:24: error: union 'Foo' has no tag",
        ".tmp_source.zig:1:13: note: consider 'union(enum)' here",
    );

    cases.add(
        "non-integer tag type to automatic union enum",
        \\const Foo = union(enum(f32)) {
        \\    A: i32,
        \\};
        \\export fn entry() void {
        \\    const x = @TagType(Foo);
        \\}
    ,
        ".tmp_source.zig:1:23: error: expected integer tag type, found 'f32'",
    );

    cases.add(
        "non-enum tag type passed to union",
        \\const Foo = union(u32) {
        \\    A: i32,
        \\};
        \\export fn entry() void {
        \\    const x = @TagType(Foo);
        \\}
    ,
        ".tmp_source.zig:1:18: error: expected enum tag type, found 'u32'",
    );

    cases.add(
        "union auto-enum value already taken",
        \\const MultipleChoice = union(enum(u32)) {
        \\    A = 20,
        \\    B = 40,
        \\    C = 60,
        \\    D = 1000,
        \\    E = 60,
        \\};
        \\export fn entry() void {
        \\    var x = MultipleChoice { .C = {} };
        \\}
    ,
        ".tmp_source.zig:6:9: error: enum tag value 60 already taken",
        ".tmp_source.zig:4:9: note: other occurrence here",
    );

    cases.add(
        "union enum field does not match enum",
        \\const Letter = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\const Payload = union(Letter) {
        \\    A: i32,
        \\    B: f64,
        \\    C: bool,
        \\    D: bool,
        \\};
        \\export fn entry() void {
        \\    var a = Payload {.A = 1234};
        \\}
    ,
        ".tmp_source.zig:10:5: error: enum field not found: 'D'",
        ".tmp_source.zig:1:16: note: enum declared here",
    );

    cases.add(
        "field type supplied in an enum",
        \\const Letter = enum {
        \\    A: void,
        \\    B,
        \\    C,
        \\};
        \\export fn entry() void {
        \\    var b = Letter.B;
        \\}
    ,
        ".tmp_source.zig:2:8: error: structs and unions, not enums, support field types",
        ".tmp_source.zig:1:16: note: consider 'union(enum)' here",
    );

    cases.add(
        "struct field missing type",
        \\const Letter = struct {
        \\    A,
        \\};
        \\export fn entry() void {
        \\    var a = Letter { .A = {} };
        \\}
    ,
        ".tmp_source.zig:2:5: error: struct field missing type",
    );

    cases.add(
        "extern union field missing type",
        \\const Letter = extern union {
        \\    A,
        \\};
        \\export fn entry() void {
        \\    var a = Letter { .A = {} };
        \\}
    ,
        ".tmp_source.zig:2:5: error: union field missing type",
    );

    cases.add(
        "extern union given enum tag type",
        \\const Letter = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\const Payload = extern union(Letter) {
        \\    A: i32,
        \\    B: f64,
        \\    C: bool,
        \\};
        \\export fn entry() void {
        \\    var a = Payload { .A = 1234 };
        \\}
    ,
        ".tmp_source.zig:6:29: error: extern union does not support enum tag type",
    );

    cases.add(
        "packed union given enum tag type",
        \\const Letter = enum {
        \\    A,
        \\    B,
        \\    C,
        \\};
        \\const Payload = packed union(Letter) {
        \\    A: i32,
        \\    B: f64,
        \\    C: bool,
        \\};
        \\export fn entry() void {
        \\    var a = Payload { .A = 1234 };
        \\}
    ,
        ".tmp_source.zig:6:29: error: packed union does not support enum tag type",
    );

    cases.add(
        "switch on union with no attached enum",
        \\const Payload = union {
        \\    A: i32,
        \\    B: f64,
        \\    C: bool,
        \\};
        \\export fn entry() void {
        \\    const a = Payload { .A = 1234 };
        \\    foo(a);
        \\}
        \\fn foo(a: *const Payload) void {
        \\    switch (a.*) {
        \\        Payload.A => {},
        \\        else => unreachable,
        \\    }
        \\}
    ,
        ".tmp_source.zig:11:14: error: switch on union which has no attached enum",
        ".tmp_source.zig:1:17: note: consider 'union(enum)' here",
    );

    cases.add(
        "enum in field count range but not matching tag",
        \\const Foo = enum(u32) {
        \\    A = 10,
        \\    B = 11,
        \\};
        \\export fn entry() void {
        \\    var x = @intToEnum(Foo, 0);
        \\}
    ,
        ".tmp_source.zig:6:13: error: enum 'Foo' has no tag matching integer value 0",
        ".tmp_source.zig:1:13: note: 'Foo' declared here",
    );

    cases.add(
        "comptime cast enum to union but field has payload",
        \\const Letter = enum { A, B, C };
        \\const Value = union(Letter) {
        \\    A: i32,
        \\    B,
        \\    C,
        \\};
        \\export fn entry() void {
        \\    var x: Value = Letter.A;
        \\}
    ,
        ".tmp_source.zig:8:26: error: cast to union 'Value' must initialize 'i32' field 'A'",
        ".tmp_source.zig:3:5: note: field 'A' declared here",
    );

    cases.add(
        "runtime cast to union which has non-void fields",
        \\const Letter = enum { A, B, C };
        \\const Value = union(Letter) {
        \\    A: i32,
        \\    B,
        \\    C,
        \\};
        \\export fn entry() void {
        \\    foo(Letter.A);
        \\}
        \\fn foo(l: Letter) void {
        \\    var x: Value = l;
        \\}
    ,
        ".tmp_source.zig:11:20: error: runtime cast to union 'Value' which has non-void fields",
        ".tmp_source.zig:3:5: note: field 'A' has type 'i32'",
    );

    cases.add(
        "taking offset of void field in struct",
        \\const Empty = struct {
        \\    val: void,
        \\};
        \\export fn foo() void {
        \\    const fieldOffset = @offsetOf(Empty, "val",);
        \\}
    ,
        ".tmp_source.zig:5:42: error: zero-bit field 'val' in struct 'Empty' has no offset",
    );

    cases.add(
        "invalid union field access in comptime",
        \\const Foo = union {
        \\    Bar: u8,
        \\    Baz: void,
        \\};
        \\comptime {
        \\    var foo = Foo {.Baz = {}};    
        \\    const bar_val = foo.Bar;
        \\}
    ,
        ".tmp_source.zig:7:24: error: accessing union field 'Bar' while field 'Baz' is set",
    );

    cases.add(
        "getting return type of generic function",
        \\fn generic(a: var) void {}
        \\comptime {
        \\    _ = @typeOf(generic).ReturnType;
        \\}
    ,
        ".tmp_source.zig:3:25: error: ReturnType has not been resolved because 'fn(var)var' is generic",
    );

    cases.add(
        "getting @ArgType of generic function",
        \\fn generic(a: var) void {}
        \\comptime {
        \\    _ = @ArgType(@typeOf(generic), 0);
        \\}
    ,
        ".tmp_source.zig:3:36: error: @ArgType could not resolve the type of arg 0 because 'fn(var)var' is generic",
    );
}
