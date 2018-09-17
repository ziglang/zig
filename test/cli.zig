const std = @import("std");
const os = std.os;
const assertOrPanic = std.debug.assertOrPanic;

var a: *std.mem.Allocator = undefined;

pub fn main() !void {
    var direct_allocator = std.heap.DirectAllocator.init();
    defer direct_allocator.deinit();

    var arena = std.heap.ArenaAllocator.init(&direct_allocator.allocator);
    defer arena.deinit();

    var arg_it = os.args();

    // skip my own exe name
    _ = arg_it.skip();

    a = &arena.allocator;

    const zig_exe_rel = try (arg_it.next(a) orelse {
        std.debug.warn("Expected first argument to be path to zig compiler\n");
        return error.InvalidArgs;
    });
    const cache_root = try (arg_it.next(a) orelse {
        std.debug.warn("Expected second argument to be cache root directory path\n");
        return error.InvalidArgs;
    });
    const zig_exe = try os.path.resolve(a, zig_exe_rel);

    try testZigInitLib(zig_exe, cache_root);
    try testZigInitExe(zig_exe, cache_root);
}

fn unwrapArg(arg: UnwrapArgError![]u8) UnwrapArgError![]u8 {
    return arg catch |err| {
        warn("Unable to parse command line: {}\n", err);
        return err;
    };
}

fn printCmd(cwd: []const u8, argv: []const []const u8) void {
    std.debug.warn("cd {} && ", cwd);
    for (argv) |arg| {
        std.debug.warn("{} ", arg);
    }
    std.debug.warn("\n");
}

fn exec(cwd: []const u8, argv: []const []const u8) !os.ChildProcess.ExecResult {
    const max_output_size = 100 * 1024;
    const result = os.ChildProcess.exec(a, argv, cwd, null, max_output_size) catch |err| {
        std.debug.warn("The following command failed:\n");
        printCmd(cwd, argv);
        return err;
    };
    switch (result.term) {
        os.ChildProcess.Term.Exited => |code| {
            if (code != 0) {
                std.debug.warn("The following command exited with error code {}:\n", code);
                printCmd(cwd, argv);
                std.debug.warn("stderr:\n{}\n", result.stderr);
                return error.CommandFailed;
            }
        },
        else => {
            std.debug.warn("The following command terminated unexpectedly:\n");
            printCmd(cwd, argv);
            std.debug.warn("stderr:\n{}\n", result.stderr);
            return error.CommandFailed;
        },
    }
    return result;
}

fn testZigInitLib(zig_exe: []const u8, cache_root: []const u8) !void {
    const dir_path = try os.path.join(a, cache_root, "clitest");
    try os.deleteTree(a, dir_path);
    try os.makeDir(dir_path);
    _ = try exec(dir_path, [][]const u8{ zig_exe, "init-lib" });
    const test_result = try exec(dir_path, [][]const u8{ zig_exe, "build", "test" });
    assertOrPanic(std.mem.endsWith(u8, test_result.stderr, "All tests passed.\n"));
}

fn testZigInitExe(zig_exe: []const u8, cache_root: []const u8) !void {
    const dir_path = try os.path.join(a, cache_root, "clitest");
    try os.deleteTree(a, dir_path);
    try os.makeDir(dir_path);
    _ = try exec(dir_path, [][]const u8{ zig_exe, "init-exe" });
    const run_result = try exec(dir_path, [][]const u8{ zig_exe, "build", "run" });
    assertOrPanic(std.mem.eql(u8, run_result.stderr, "All your base are belong to us.\n"));
}
