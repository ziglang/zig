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
        const case = ctx.obj("isolated carriage return in multiline string literal", .{});
        case.backend = .stage2;

        case.addError("const foo = \\\\\test\r\r rogue carriage return\n;", &[_][]const u8{
            ":1:19: error: expected ';' after declaration",
            ":1:20: note: invalid byte: '\\r'",
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

    {
        const case = ctx.obj("argument causes error", .{});
        case.backend = .stage2;

        case.addSourceFile("b.zig",
            \\pub const ElfDynLib = struct {
            \\    pub fn lookup(self: *ElfDynLib, comptime T: type) ?T {
            \\        _ = self;
            \\        return undefined;
            \\    }
            \\};
        );

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
    }

    {
        const case = ctx.obj("astgen failure in file struct", .{});
        case.backend = .stage2;

        case.addSourceFile("b.zig",
            \\+
        );

        case.addError(
            \\pub export fn entry() void {
            \\    _ = (@sizeOf(@import("b.zig")));
            \\}
        , &[_][]const u8{
            ":1:1: error: expected type expression, found '+'",
        });
    }

    {
        const case = ctx.obj("invalid store to comptime field", .{});
        case.backend = .stage2;

        case.addSourceFile("a.zig",
            \\pub const S = struct {
            \\    comptime foo: u32 = 1,
            \\    bar: u32,
            \\    pub fn foo(x: @This()) void {
            \\        _ = x;
            \\    }
            \\};
        );

        case.addError(
            \\const a = @import("a.zig");
            \\
            \\export fn entry() void {
            \\    _ = a.S.foo(a.S{ .foo = 2, .bar = 2 });
            \\}
        , &[_][]const u8{
            ":4:23: error: value stored in comptime field does not match the default value of the field",
            ":2:25: note: default value set here",
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

    {
        const case = ctx.obj("file in multiple modules", .{});
        case.backend = .stage2;

        case.addSourceFile("foo.zig",
            \\const dummy = 0;
        );

        case.addDepModule("foo", "foo.zig");

        case.addError(
            \\comptime {
            \\    _ = @import("foo");
            \\    _ = @import("foo.zig");
            \\}
        , &[_][]const u8{
            ":1:1: error: file exists in multiple modules",
            ":1:1: note: root of module root.foo",
            ":3:17: note: imported from module root",
        });
    }
}
