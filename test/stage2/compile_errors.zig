const TestContext = @import("../../src-self-hosted/test.zig").TestContext;
const std = @import("std");

const ErrorMsg = @import("../../src-self-hosted/Module.zig").ErrorMsg;

const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    ctx.compileErrorZIR("call undefined local", linux_x64,
        \\@noreturn = primitive(noreturn)
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@start = fn(@start_fnty, {
        \\  %0 = call(%test, [])
        \\})
 // TODO: address inconsistency in this message and the one in the next test
            , &[_][]const u8{":5:13: error: unrecognized identifier: %test"});

    ctx.compileErrorZIR("call with non-existent target", linux_x64,
        \\@noreturn = primitive(noreturn)
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@start = fn(@start_fnty, {
        \\  %0 = call(@notafunc, [])
        \\})
        \\@0 = str("_start")
        \\@1 = export(@0, "start")
    , &[_][]const u8{":5:13: error: decl 'notafunc' not found"});

    // TODO: this error should occur at the call site, not the fntype decl
    ctx.compileErrorZIR("call naked function", linux_x64,
        \\@noreturn = primitive(noreturn)
        \\
        \\@start_fnty = fntype([], @noreturn, cc=Naked)
        \\@s = fn(@start_fnty, {})
        \\@start = fn(@start_fnty, {
        \\  %0 = call(@s, [])
        \\})
        \\@0 = str("_start")
        \\@1 = export(@0, "start")
    , &[_][]const u8{":4:9: error: unable to call function with naked calling convention"});

    ctx.incrementalFailureZIR("exported symbol collision", linux_x64,
        \\@noreturn = primitive(noreturn)
        \\
        \\@start_fnty = fntype([], @noreturn)
        \\@start = fn(@start_fnty, {})
        \\
        \\@0 = str("_start")
        \\@1 = export(@0, "start")
        \\@2 = export(@0, "start")
    , &[_][]const u8{":8:13: error: exported symbol collision: _start"},
        \\@noreturn = primitive(noreturn)
        \\
        \\@start_fnty = fntype([], @noreturn)
        \\@start = fn(@start_fnty, {})
        \\
        \\@0 = str("_start")
        \\@1 = export(@0, "start")
    );
}
