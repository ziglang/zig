const std = @import("std");
const builtin = @import("builtin");
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

    const dir_path = try os.path.join(a, cache_root, "clitest");
    const TestFn = fn ([]const u8, []const u8) error!void;
    const test_fns = []TestFn{
        testZigInitLib,
        testZigInitExe,
        testGodboltApi,
    };
    for (test_fns) |testFn| {
        try os.deleteTree(a, dir_path);
        try os.makeDir(dir_path);
        try testFn(zig_exe, dir_path);
    }
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

fn testZigInitLib(zig_exe: []const u8, dir_path: []const u8) !void {
    _ = try exec(dir_path, [][]const u8{ zig_exe, "init-lib" });
    const test_result = try exec(dir_path, [][]const u8{ zig_exe, "build", "test" });
    assertOrPanic(std.mem.endsWith(u8, test_result.stderr, "All tests passed.\n"));
}

fn testZigInitExe(zig_exe: []const u8, dir_path: []const u8) !void {
    _ = try exec(dir_path, [][]const u8{ zig_exe, "init-exe" });
    const run_result = try exec(dir_path, [][]const u8{ zig_exe, "build", "run" });
    assertOrPanic(std.mem.eql(u8, run_result.stderr, "All your base are belong to us.\n"));
}

fn testGodboltApi(zig_exe: []const u8, dir_path: []const u8) anyerror!void {
    if (builtin.os != builtin.Os.linux or builtin.arch != builtin.Arch.x86_64) return;

    const example_zig_path = try os.path.join(a, dir_path, "example.zig");
    const example_s_path = try os.path.join(a, dir_path, "example.s");

    try std.io.writeFile(example_zig_path,
        \\// Type your code here, or load an example.
        \\export fn square(num: i32) i32 {
        \\    return num * num;
        \\}
        \\extern fn zig_panic() noreturn;
        \\pub inline fn panic(msg: []const u8, error_return_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    zig_panic();
        \\}
    );

    const args = [][]const u8{
        zig_exe, "build-obj",
        "--cache-dir", dir_path,
        "--output", example_s_path,
        "--output-h", "/dev/null",
        "--emit", "asm",
        "-mllvm", "--x86-asm-syntax=intel",
        "--strip", "--release-fast",
        example_zig_path,
    };
    _ = try exec(dir_path, args);

    const out_asm = try std.io.readFileAlloc(a, example_s_path);
    assertOrPanic(std.mem.indexOf(u8, out_asm, "square:") != null);
    assertOrPanic(std.mem.indexOf(u8, out_asm, "imul\tedi, edi") != null);
}
