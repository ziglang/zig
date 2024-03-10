const std = @import("../std.zig");
const valgrind = std.valgrind;

pub const CachegrindClientRequest = enum(usize) {
    StartInstrumentation = valgrind.ToolBase("CG".*),
    StopInstrumentation,
};

fn doCachegrindClientRequestExpr(default: usize, request: CachegrindClientRequest, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize) usize {
    return valgrind.doClientRequest(default, @as(usize, @intCast(@intFromEnum(request))), a1, a2, a3, a4, a5);
}

fn doCachegrindClientRequestStmt(request: CachegrindClientRequest, a1: usize, a2: usize, a3: usize, a4: usize, a5: usize) void {
    _ = doCachegrindClientRequestExpr(0, request, a1, a2, a3, a4, a5);
}

/// Start Cachegrind instrumentation if not already enabled. Use this in
/// combination with `std.valgrind.cachegrind.stopInstrumentation` and
/// `--instr-at-start` to measure only part of a client program's execution.
pub fn startInstrumentation() void {
    doCachegrindClientRequestStmt(.StartInstrumentation, 0, 0, 0, 0, 0);
}

/// Stop Cachegrind instrumentation if not already disabled. Use this in
/// combination with `std.valgrind.cachegrind.startInstrumentation` and
/// `--instr-at-start` to measure only part of a client program's execution.
pub fn stopInstrumentation() void {
    doCachegrindClientRequestStmt(.StopInstrumentation, 0, 0, 0, 0, 0);
}
