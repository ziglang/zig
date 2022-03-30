const std = @import("std");
const builtin = @import("builtin");
const TestContext = @import("../src/test.zig").TestContext;

pub fn addCases(ctx: *TestContext) !void {
    var parent_dir = try std.fs.cwd().openDir(std.fs.path.dirname(@src().file).?, .{ .no_follow = true });
    defer parent_dir.close();

    var compile_errors_dir = try parent_dir.openDir("compile_errors", .{ .no_follow = true });
    defer compile_errors_dir.close();

    {
        var stage2_dir = try compile_errors_dir.openDir("stage2", .{ .iterate = true, .no_follow = true });
        defer stage2_dir.close();

        // TODO make this false once the bug is solved that it triggers
        const one_test_case_per_file = true;
        try ctx.addErrorCasesFromDir("stage2", stage2_dir, .stage2, .Obj, false, one_test_case_per_file);
    }

    {
        var stage1_dir = try compile_errors_dir.openDir("stage1", .{ .no_follow = true });
        defer stage1_dir.close();
        {
            const one_test_case_per_file = true;

            var obj_dir = try stage1_dir.openDir("obj", .{ .iterate = true, .no_follow = true });
            defer obj_dir.close();

            try ctx.addErrorCasesFromDir("stage1", obj_dir, .stage1, .Obj, false, one_test_case_per_file);

            var exe_dir = try stage1_dir.openDir("exe", .{ .iterate = true, .no_follow = true });
            defer exe_dir.close();

            try ctx.addErrorCasesFromDir("stage1", exe_dir, .stage1, .Exe, false, one_test_case_per_file);

            var test_dir = try stage1_dir.openDir("test", .{ .iterate = true, .no_follow = true });
            defer test_dir.close();

            try ctx.addErrorCasesFromDir("stage1", test_dir, .stage1, .Exe, true, one_test_case_per_file);
        }
    }

    {
        const case = ctx.obj("callconv(.Interrupt) on unsupported platform", .{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
            .abi = .none,
        });
        case.backend = .stage1;
        case.addError(
            \\export fn entry() callconv(.Interrupt) void {}
        , &[_][]const u8{
            "tmp.zig:1:28: error: callconv 'Interrupt' is only available on x86, x86_64, AVR, and MSP430, not aarch64",
        });
    }
    {
        var case = ctx.obj("callconv(.Signal) on unsupported platform", .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .none,
        });
        case.backend = .stage1;
        case.addError(
            \\export fn entry() callconv(.Signal) void {}
        , &[_][]const u8{
            "tmp.zig:1:28: error: callconv 'Signal' is only available on AVR, not x86_64",
        });
    }
    {
        const case = ctx.obj("callconv(.Stdcall, .Fastcall, .Thiscall) on unsupported platform", .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .none,
        });
        case.backend = .stage1;
        case.addError(
            \\const F1 = fn () callconv(.Stdcall) void;
            \\const F2 = fn () callconv(.Fastcall) void;
            \\const F3 = fn () callconv(.Thiscall) void;
            \\export fn entry1() void { var a: F1 = undefined; _ = a; }
            \\export fn entry2() void { var a: F2 = undefined; _ = a; }
            \\export fn entry3() void { var a: F3 = undefined; _ = a; }
        , &[_][]const u8{
            "tmp.zig:1:27: error: callconv 'Stdcall' is only available on x86, not x86_64",
            "tmp.zig:2:27: error: callconv 'Fastcall' is only available on x86, not x86_64",
            "tmp.zig:3:27: error: callconv 'Thiscall' is only available on x86, not x86_64",
        });
    }
    {
        const case = ctx.obj("callconv(.Stdcall, .Fastcall, .Thiscall) on unsupported platform", .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .none,
        });
        case.backend = .stage1;
        case.addError(
            \\export fn entry1() callconv(.Stdcall) void {}
            \\export fn entry2() callconv(.Fastcall) void {}
            \\export fn entry3() callconv(.Thiscall) void {}
        , &[_][]const u8{
            "tmp.zig:1:29: error: callconv 'Stdcall' is only available on x86, not x86_64",
            "tmp.zig:2:29: error: callconv 'Fastcall' is only available on x86, not x86_64",
            "tmp.zig:3:29: error: callconv 'Thiscall' is only available on x86, not x86_64",
        });
    }
    {
        const case = ctx.obj("callconv(.Vectorcall) on unsupported platform", .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .none,
        });
        case.backend = .stage1;
        case.addError(
            \\export fn entry() callconv(.Vectorcall) void {}
        , &[_][]const u8{
            "tmp.zig:1:28: error: callconv 'Vectorcall' is only available on x86 and AArch64, not x86_64",
        });
    }
    {
        const case = ctx.obj("callconv(.APCS, .AAPCS, .AAPCSVFP) on unsupported platform", .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .none,
        });
        case.backend = .stage1;
        case.addError(
            \\export fn entry1() callconv(.APCS) void {}
            \\export fn entry2() callconv(.AAPCS) void {}
            \\export fn entry3() callconv(.AAPCSVFP) void {}
        , &[_][]const u8{
            "tmp.zig:1:29: error: callconv 'APCS' is only available on ARM, not x86_64",
            "tmp.zig:2:29: error: callconv 'AAPCS' is only available on ARM, not x86_64",
            "tmp.zig:3:29: error: callconv 'AAPCSVFP' is only available on ARM, not x86_64",
        });
    }

    {
        const case = ctx.obj("call with new stack on unsupported target", .{
            .cpu_arch = .wasm32,
            .os_tag = .wasi,
            .abi = .none,
        });
        case.backend = .stage1;
        case.addError(
            \\var buf: [10]u8 align(16) = undefined;
            \\export fn entry() void {
            \\    @call(.{.stack = &buf}, foo, .{});
            \\}
            \\fn foo() void {}
        , &[_][]const u8{
            "tmp.zig:3:5: error: target arch 'wasm32' does not support calling with a new stack",
        });
    }

    // Note: One of the error messages here is backwards. It would be nice to fix, but that's not
    // going to stop me from merging this branch which fixes a bunch of other stuff.
    ctx.objErrStage1("incompatible sentinels",
        \\export fn entry1(ptr: [*:255]u8) [*:0]u8 {
        \\    return ptr;
        \\}
        \\export fn entry2(ptr: [*]u8) [*:0]u8 {
        \\    return ptr;
        \\}
        \\export fn entry3() void {
        \\    var array: [2:0]u8 = [_:255]u8{1, 2};
        \\    _ = array;
        \\}
        \\export fn entry4() void {
        \\    var array: [2:0]u8 = [_]u8{1, 2};
        \\    _ = array;
        \\}
    , &[_][]const u8{
        "tmp.zig:2:12: error: expected type '[*:0]u8', found '[*:255]u8'",
        "tmp.zig:2:12: note: destination pointer requires a terminating '0' sentinel, but source pointer has a terminating '255' sentinel",
        "tmp.zig:5:12: error: expected type '[*:0]u8', found '[*]u8'",
        "tmp.zig:5:12: note: destination pointer requires a terminating '0' sentinel",

        "tmp.zig:8:35: error: expected type '[2:255]u8', found '[2:0]u8'",
        "tmp.zig:8:35: note: destination array requires a terminating '255' sentinel, but source array has a terminating '0' sentinel",
        "tmp.zig:12:31: error: expected type '[2:0]u8', found '[2]u8'",
        "tmp.zig:12:31: note: destination array requires a terminating '0' sentinel",
    });

    {
        const case = ctx.obj("variable in inline assembly template cannot be found", .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .gnu,
        });
        case.backend = .stage1;
        case.addError(
            \\export fn entry() void {
            \\    var sp = asm volatile (
            \\        "mov %[foo], sp"
            \\        : [bar] "=r" (-> usize)
            \\    );
            \\    _ = sp;
            \\}
        , &[_][]const u8{
            "tmp.zig:2:14: error: could not find 'foo' in the inputs or outputs",
        });
    }

    {
        const case = ctx.obj("bad alignment in @asyncCall", .{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
            .abi = .none,
        });
        case.backend = .stage1;
        case.addError(
            \\export fn entry() void {
            \\    var ptr: fn () callconv(.Async) void = func;
            \\    var bytes: [64]u8 = undefined;
            \\    _ = @asyncCall(&bytes, {}, ptr, .{});
            \\}
            \\fn func() callconv(.Async) void {}
        , &[_][]const u8{
            "tmp.zig:4:21: error: expected type '[]align(8) u8', found '*[64]u8'",
        });
    }

    if (builtin.os.tag == .linux) {
        ctx.testErrStage1("implicit dependency on libc",
            \\extern "c" fn exit(u8) void;
            \\export fn entry() void {
            \\    exit(0);
            \\}
        , &[_][]const u8{
            "tmp.zig:3:5: error: dependency on libc must be explicitly specified in the build command",
        });

        ctx.testErrStage1("libc headers note",
            \\const c = @cImport(@cInclude("stdio.h"));
            \\export fn entry() void {
            \\    _ = c.printf("hello, world!\n");
            \\}
        , &[_][]const u8{
            "tmp.zig:1:11: error: C import failed",
            "tmp.zig:1:11: note: libc headers not available; compilation does not link against libc",
        });
    }

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
        const case = ctx.obj("align(N) expr function pointers is a compile error", .{
            .cpu_arch = .wasm32,
            .os_tag = .freestanding,
            .abi = .none,
        });
        case.backend = .stage1;

        case.addError(
            \\export fn foo() align(1) void {
            \\    return;
            \\}
        , &[_][]const u8{
            "tmp.zig:1:23: error: align(N) expr is not allowed on function prototypes in wasm32/wasm64",
        });
    }
}
