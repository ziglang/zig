const std = @import("std");
const builtin = @import("builtin");
const Cases = @import("src/Cases.zig");

pub fn addCases(ctx: *Cases, b: *std.Build) !void {
    {
        const case = ctx.obj("multiline error messages", b.graph.host);

        case.addError(
            \\comptime {
            \\    @compileError("hello\nworld");
            \\}
        , &[_][]const u8{
            \\:2:5: error: hello
            \\             world
        });

        case.addError(
            \\comptime {
            \\    @compileError(
            \\        \\
            \\        \\hello!
            \\        \\I'm a multiline error message.
            \\        \\I hope to be very useful!
            \\        \\
            \\        \\also I will leave this trailing newline here if you don't mind
            \\        \\
            \\    );
            \\}
        , &[_][]const u8{
            \\:2:5: error: 
            \\             hello!
            \\             I'm a multiline error message.
            \\             I hope to be very useful!
            \\             
            \\             also I will leave this trailing newline here if you don't mind
            \\             
        });
    }

    {
        const case = ctx.obj("missing semicolon at EOF", b.graph.host);
        case.addError(
            \\const foo = 1
        , &[_][]const u8{
            \\:1:14: error: expected ';' after declaration
        });
    }

    {
        const case = ctx.obj("argument causes error", b.graph.host);

        case.addError(
            \\pub export fn entry() void {
            \\    var lib: @import("b.zig").ElfDynLib = undefined;
            \\    _ = lib.lookup(fn () void);
            \\}
        , &[_][]const u8{
            ":3:12: error: unable to resolve comptime value",
            ":3:12: note: argument to function being called at comptime must be comptime-known",
            ":2:55: note: expression is evaluated at comptime because the generic function was instantiated with a comptime-only return type",
        });
        case.addSourceFile("b.zig",
            \\pub const ElfDynLib = struct {
            \\    pub fn lookup(self: *ElfDynLib, comptime T: type) ?T {
            \\        _ = self;
            \\        return undefined;
            \\    }
            \\};
        );
    }

    {
        const case = ctx.obj("astgen failure in file struct", b.graph.host);

        case.addError(
            \\pub export fn entry() void {
            \\    _ = (@sizeOf(@import("b.zig")));
            \\}
        , &[_][]const u8{
            ":1:1: error: expected type expression, found '+'",
        });
        case.addSourceFile("b.zig",
            \\+
        );
    }

    {
        const case = ctx.obj("invalid store to comptime field", b.graph.host);

        case.addError(
            \\const a = @import("a.zig");
            \\
            \\export fn entry() void {
            \\    _ = a.S.qux(a.S{ .foo = 2, .bar = 2 });
            \\}
        , &[_][]const u8{
            ":4:23: error: value stored in comptime field does not match the default value of the field",
            ":2:25: note: default value set here",
        });
        case.addSourceFile("a.zig",
            \\pub const S = struct {
            \\    comptime foo: u32 = 1,
            \\    bar: u32,
            \\    pub fn qux(x: @This()) void {
            \\        _ = x;
            \\    }
            \\};
        );
    }

    {
        const case = ctx.obj("file in multiple modules", b.graph.host);
        case.addDepModule("foo", "foo.zig");

        case.addError(
            \\comptime {
            \\    _ = @import("foo");
            \\    _ = @import("foo.zig");
            \\}
        , &[_][]const u8{
            ":1:1: error: file exists in multiple modules",
            ":1:1: note: root of module foo",
            ":3:17: note: imported from module root",
        });
        case.addSourceFile("foo.zig",
            \\const dummy = 0;
        );
    }

    {
        const case = ctx.obj("wrong same named struct", b.graph.host);

        case.addError(
            \\const a = @import("a.zig");
            \\const b = @import("b.zig");
            \\
            \\export fn entry() void {
            \\    var a1: a.Foo = undefined;
            \\    bar(&a1);
            \\}
            \\
            \\fn bar(_: *b.Foo) void {}
        , &[_][]const u8{
            ":6:9: error: expected type '*b.Foo', found '*a.Foo'",
            ":6:9: note: pointer type child 'a.Foo' cannot cast into pointer type child 'b.Foo'",
            ":1:17: note: struct declared here",
            ":1:17: note: struct declared here",
            ":9:11: note: parameter type declared here",
        });

        case.addSourceFile("a.zig",
            \\pub const Foo = struct {
            \\    x: i32,
            \\};
        );

        case.addSourceFile("b.zig",
            \\pub const Foo = struct {
            \\    z: f64,
            \\};
        );
    }

    {
        const case = ctx.obj("non-printable invalid character", b.graph.host);

        case.addError("\xff\xfe" ++
            \\export fn foo() bool {
            \\    return true;
            \\}
        , &[_][]const u8{
            ":1:1: error: expected type expression, found 'invalid token'",
        });
    }

    {
        const case = ctx.obj("imported generic method call with invalid param", b.graph.host);

        case.addError(
            \\pub const import = @import("import.zig");
            \\
            \\export fn callComptimeBoolFunctionWithRuntimeBool(x: bool) void {
            \\    import.comptimeBoolFunction(x);
            \\}
            \\
            \\export fn callComptimeAnytypeFunctionWithRuntimeBool(x: bool) void {
            \\    import.comptimeAnytypeFunction(x);
            \\}
            \\
            \\export fn callAnytypeFunctionWithRuntimeComptimeOnlyType(x: u32) void {
            \\    const S = struct { x: u32, y: type };
            \\    import.anytypeFunction(S{ .x = x, .y = u32 });
            \\}
        , &[_][]const u8{
            ":4:33: error: runtime-known argument passed to comptime parameter",
            ":1:38: note: declared comptime here",
            ":8:36: error: runtime-known argument passed to comptime parameter",
            ":2:41: note: declared comptime here",
            ":13:32: error: unable to resolve comptime value",
            ":13:32: note: initializer of comptime only struct must be comptime-known",
        });

        case.addSourceFile("import.zig",
            \\pub fn comptimeBoolFunction(comptime _: bool) void {}
            \\pub fn comptimeAnytypeFunction(comptime _: anytype) void {}
            \\pub fn anytypeFunction(_: anytype) void {}
        );
    }

    {
        const case = ctx.obj("invalid byte in string", b.graph.host);

        case.addError("_ = \"\x01Q\";", &[_][]const u8{
            ":1:5: error: expected expression, found 'invalid token'",
        });
    }

    {
        const case = ctx.obj("invalid byte in comment", b.graph.host);

        case.addError("//\x01Q", &[_][]const u8{
            ":1:1: error: expected type expression, found 'invalid token'",
        });
    }

    {
        const case = ctx.obj("control character in character literal", b.graph.host);

        case.addError("const c = '\x01';", &[_][]const u8{
            ":1:11: error: expected expression, found 'invalid token'",
        });
    }

    {
        const case = ctx.obj("invalid byte at start of token", b.graph.host);

        case.addError("x = \x00Q", &[_][]const u8{
            ":1:5: error: expected expression, found 'invalid token'",
        });
    }
}
