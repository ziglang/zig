const TestContext = @import("../../src-self-hosted/test.zig").TestContext;
const std = @import("std");

const ErrorMsg = @import("../../src-self-hosted/Module.zig").ErrorMsg;

const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    ctx.addZIRError("call undefined local", linux_x64,
        \\@noreturn = primitive(noreturn)
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@start = fn(@start_fnty, {
        \\  %0 = call(%test, [])
        \\})
 // TODO: address inconsistency in this message and the one in the next test
            , &[_][]const u8{":5:13: error: unrecognized identifier: %test"});

    ctx.addZIRError("call with non-existent target", linux_x64,
        \\@noreturn = primitive(noreturn)
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@start = fn(@start_fnty, {
        \\  %0 = call(@notafunc, [])
        \\})
        \\@0 = str("_start")
        \\@1 = ref(@0)
        \\@2 = export(@1, @start)
    , &[_][]const u8{":5:13: error: use of undeclared identifier 'notafunc'"});

    // TODO: this error should occur at the call site, not the fntype decl
    ctx.addZIRError("call naked function", linux_x64,
        \\@noreturn = primitive(noreturn)
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@s = fn(@start_fnty, {})
        \\@start = fn(@start_fnty, {
        \\  %0 = call(@s, [])
        \\})
        \\@0 = str("_start")
        \\@1 = ref(@0)
        \\@2 = export(@1, @start)
    , &[_][]const u8{":4:9: error: unable to call function with naked calling convention"});

    // TODO: re-enable these tests.
    // https://github.com/ziglang/zig/issues/1364
    // TODO: add Zig AST -> ZIR testing pipeline

    //try ctx.testCompileError(
    //    \\export fn entry() void {}
    //    \\export fn entry() void {}
    //, "1.zig", 2, 8, "exported symbol collision: 'entry'");

    //try ctx.testCompileError(
    //    \\fn() void {}
    //, "1.zig", 1, 1, "missing function name");

    //try ctx.testCompileError(
    //    \\comptime {
    //    \\    return;
    //    \\}
    //, "1.zig", 2, 5, "return expression outside function definition");

    //try ctx.testCompileError(
    //    \\export fn entry() void {
    //    \\    defer return;
    //    \\}
    //, "1.zig", 2, 11, "cannot return from defer expression");

    //try ctx.testCompileError(
    //    \\export fn entry() c_int {
    //    \\    return 36893488147419103232;
    //    \\}
    //, "1.zig", 2, 12, "integer value '36893488147419103232' cannot be stored in type 'c_int'");

    //try ctx.testCompileError(
    //    \\comptime {
    //    \\    var a: *align(4) align(4) i32 = 0;
    //    \\}
    //, "1.zig", 2, 22, "Extra align qualifier");

    //try ctx.testCompileError(
    //    \\comptime {
    //    \\    var b: *const const i32 = 0;
    //    \\}
    //, "1.zig", 2, 19, "Extra align qualifier");

    //try ctx.testCompileError(
    //    \\comptime {
    //    \\    var c: *volatile volatile i32 = 0;
    //    \\}
    //, "1.zig", 2, 22, "Extra align qualifier");

    //try ctx.testCompileError(
    //    \\comptime {
    //    \\    var d: *allowzero allowzero i32 = 0;
    //    \\}
    //, "1.zig", 2, 23, "Extra align qualifier");
}
