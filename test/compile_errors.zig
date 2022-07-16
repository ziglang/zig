const std = @import("std");
const builtin = @import("builtin");
const TestContext = @import("../src/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    {
        const case = ctx.obj("wrong same named struct", .{});
        case.backend = .stage1;

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

        case.addError(
            \\const a = @import("a.zig");
            \\const b = @import("b.zig");
            \\
            \\export fn entry() void {
            \\    var a1: a.Foo = undefined;
            \\    bar(&a1);
            \\}
            \\
            \\fn bar(x: *b.Foo) void {_ = x;}
        , &[_][]const u8{
            "tmp.zig:6:10: error: expected type '*b.Foo', found '*a.Foo'",
            "tmp.zig:6:10: note: pointer type child 'a.Foo' cannot cast into pointer type child 'b.Foo'",
            "a.zig:1:17: note: a.Foo declared here",
            "b.zig:1:17: note: b.Foo declared here",
        });
    }

    {
        const case = ctx.obj("multiple files with private function error", .{});
        case.backend = .stage1;

        case.addSourceFile("foo.zig",
            \\fn privateFunction() void { }
        );

        case.addError(
            \\const foo = @import("foo.zig",);
            \\
            \\export fn callPrivFunction() void {
            \\    foo.privateFunction();
            \\}
        , &[_][]const u8{
            "tmp.zig:4:8: error: 'privateFunction' is private",
            "foo.zig:1:1: note: declared here",
        });
    }

    {
        const case = ctx.obj("multiple files with private member instance function (canonical invocation) error", .{});
        case.backend = .stage1;

        case.addSourceFile("foo.zig",
            \\pub const Foo = struct {
            \\    fn privateFunction(self: *Foo) void { _ = self; }
            \\};
        );

        case.addError(
            \\const Foo = @import("foo.zig",).Foo;
            \\
            \\export fn callPrivFunction() void {
            \\    var foo = Foo{};
            \\    Foo.privateFunction(foo);
            \\}
        , &[_][]const u8{
            "tmp.zig:5:8: error: 'privateFunction' is private",
            "foo.zig:2:5: note: declared here",
        });
    }

    {
        const case = ctx.obj("multiple files with private member instance function error", .{});
        case.backend = .stage1;

        case.addSourceFile("foo.zig",
            \\pub const Foo = struct {
            \\    fn privateFunction(self: *Foo) void { _ = self; }
            \\};
        );

        case.addError(
            \\const Foo = @import("foo.zig",).Foo;
            \\
            \\export fn callPrivFunction() void {
            \\    var foo = Foo{};
            \\    foo.privateFunction();
            \\}
        , &[_][]const u8{
            "tmp.zig:5:8: error: 'privateFunction' is private",
            "foo.zig:2:5: note: declared here",
        });
    }

    {
        const case = ctx.obj("export collision", .{});
        case.backend = .stage1;

        case.addSourceFile("foo.zig",
            \\export fn bar() void {}
            \\pub const baz = 1234;
        );

        case.addError(
            \\const foo = @import("foo.zig",);
            \\
            \\export fn bar() usize {
            \\    return foo.baz;
            \\}
        , &[_][]const u8{
            "foo.zig:1:1: error: exported symbol collision: 'bar'",
            "tmp.zig:3:1: note: other symbol here",
        });
    }

    ctx.objErrStage1("non-printable invalid character", "\xff\xfe" ++
        "fn foo() bool {\r\n" ++
        "    return true;\r\n" ++
        "}\r\n", &[_][]const u8{
        "tmp.zig:1:1: error: expected test, comptime, var decl, or container field, found 'invalid bytes'",
        "tmp.zig:1:1: note: invalid byte: '\\xff'",
    });

    ctx.objErrStage1("non-printable invalid character with escape alternative", "fn foo() bool {\n" ++
        "\treturn true;\n" ++
        "}\n", &[_][]const u8{
        "tmp.zig:2:1: error: invalid character: '\\t'",
    });

    {
        const case = ctx.obj("multiline error messages", .{});
        case.backend = .stage2;

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
        const case = ctx.obj("missing semicolon at EOF", .{});
        case.addError(
            \\const foo = 1
        , &[_][]const u8{
            \\:1:14: error: expected ';' after declaration
        });
    }

    // TODO test this in stage2, but we won't even try in stage1
    //ctx.objErrStage1("inline fn calls itself indirectly",
    //    \\export fn foo() void {
    //    \\    bar();
    //    \\}
    //    \\fn bar() callconv(.Inline) void {
    //    \\    baz();
    //    \\    quux();
    //    \\}
    //    \\fn baz() callconv(.Inline) void {
    //    \\    bar();
    //    \\    quux();
    //    \\}
    //    \\extern fn quux() void;
    //, &[_][]const u8{
    //    "tmp.zig:4:1: error: unable to inline function",
    //});

    //ctx.objErrStage1("save reference to inline function",
    //    \\export fn foo() void {
    //    \\    quux(@ptrToInt(bar));
    //    \\}
    //    \\fn bar() callconv(.Inline) void { }
    //    \\extern fn quux(usize) void;
    //, &[_][]const u8{
    //    "tmp.zig:4:1: error: unable to inline function",
    //});
}
