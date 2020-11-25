const std = @import("std");
const testing = std.testing;
const process = std.process;
const fs = std.fs;
const ChildProcess = std.ChildProcess;

var a: *std.mem.Allocator = undefined;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var arg_it = process.args();

    // skip my own exe name
    _ = arg_it.skip();

    a = &arena.allocator;

    const zig_exe_rel = try (arg_it.next(a) orelse {
        std.debug.warn("Expected first argument to be path to zig compiler\n", .{});
        return error.InvalidArgs;
    });
    const cache_root = try (arg_it.next(a) orelse {
        std.debug.warn("Expected second argument to be cache root directory path\n", .{});
        return error.InvalidArgs;
    });
    const zig_exe = try fs.path.resolve(a, &[_][]const u8{zig_exe_rel});

    const dir_path = try fs.path.join(a, &[_][]const u8{ cache_root, "clitest" });
    const TestFn = fn ([]const u8, []const u8) anyerror!void;
    const test_fns = [_]TestFn{
        testZigInitLib,
        testZigInitExe,
        testGodboltApi,
        testMissingOutputPath,
        testZigFmt,
    };
    for (test_fns) |testFn| {
        try fs.cwd().deleteTree(dir_path);
        try fs.cwd().makeDir(dir_path);
        try testFn(zig_exe, dir_path);
    }
}

fn unwrapArg(arg: UnwrapArgError![]u8) UnwrapArgError![]u8 {
    return arg catch |err| {
        warn("Unable to parse command line: {}\n", .{err});
        return err;
    };
}

fn printCmd(cwd: []const u8, argv: []const []const u8) void {
    std.debug.warn("cd {} && ", .{cwd});
    for (argv) |arg| {
        std.debug.warn("{} ", .{arg});
    }
    std.debug.warn("\n", .{});
}

fn exec(cwd: []const u8, expect_0: bool, argv: []const []const u8) !ChildProcess.ExecResult {
    const max_output_size = 100 * 1024;
    const result = ChildProcess.exec(.{
        .allocator = a,
        .argv = argv,
        .cwd = cwd,
        .max_output_bytes = max_output_size,
    }) catch |err| {
        std.debug.warn("The following command failed:\n", .{});
        printCmd(cwd, argv);
        return err;
    };
    switch (result.term) {
        .Exited => |code| {
            if ((code != 0) == expect_0) {
                std.debug.warn("The following command exited with error code {}:\n", .{code});
                printCmd(cwd, argv);
                std.debug.warn("stderr:\n{}\n", .{result.stderr});
                return error.CommandFailed;
            }
        },
        else => {
            std.debug.warn("The following command terminated unexpectedly:\n", .{});
            printCmd(cwd, argv);
            std.debug.warn("stderr:\n{}\n", .{result.stderr});
            return error.CommandFailed;
        },
    }
    return result;
}

fn testZigInitLib(zig_exe: []const u8, dir_path: []const u8) !void {
    _ = try exec(dir_path, true, &[_][]const u8{ zig_exe, "init-lib" });
    const test_result = try exec(dir_path, true, &[_][]const u8{ zig_exe, "build", "test" });
    testing.expect(std.mem.endsWith(u8, test_result.stderr, "All 1 tests passed.\n"));
}

fn testZigInitExe(zig_exe: []const u8, dir_path: []const u8) !void {
    _ = try exec(dir_path, true, &[_][]const u8{ zig_exe, "init-exe" });
    const run_result = try exec(dir_path, true, &[_][]const u8{ zig_exe, "build", "run" });
    testing.expect(std.mem.eql(u8, run_result.stderr, "info: All your codebase are belong to us.\n"));
}

fn testGodboltApi(zig_exe: []const u8, dir_path: []const u8) anyerror!void {
    if (std.Target.current.os.tag != .linux or std.Target.current.cpu.arch != .x86_64) return;

    const example_zig_path = try fs.path.join(a, &[_][]const u8{ dir_path, "example.zig" });
    const example_s_path = try fs.path.join(a, &[_][]const u8{ dir_path, "example.s" });

    try fs.cwd().writeFile(example_zig_path,
        \\// Type your code here, or load an example.
        \\export fn square(num: i32) i32 {
        \\    return num * num;
        \\}
        \\extern fn zig_panic() noreturn;
        \\pub inline fn panic(msg: []const u8, error_return_trace: ?*@import("builtin").StackTrace) noreturn {
        \\    zig_panic();
        \\}
    );

    var args = std.ArrayList([]const u8).init(a);
    try args.appendSlice(&[_][]const u8{
        zig_exe,          "build-obj",
        "--cache-dir",    dir_path,
        "--name",         "example",
        "-fno-emit-bin",  "-fno-emit-h",
        "--strip",        "-OReleaseFast",
        example_zig_path,
    });

    const emit_asm_arg = try std.fmt.allocPrint(a, "-femit-asm={s}", .{example_s_path});
    try args.append(emit_asm_arg);

    _ = try exec(dir_path, true, args.items);

    const out_asm = try std.fs.cwd().readFileAlloc(a, example_s_path, std.math.maxInt(usize));
    testing.expect(std.mem.indexOf(u8, out_asm, "square:") != null);
    testing.expect(std.mem.indexOf(u8, out_asm, "mov\teax, edi") != null);
    testing.expect(std.mem.indexOf(u8, out_asm, "imul\teax, edi") != null);
}

fn testMissingOutputPath(zig_exe: []const u8, dir_path: []const u8) !void {
    _ = try exec(dir_path, true, &[_][]const u8{ zig_exe, "init-exe" });
    const output_path = try fs.path.join(a, &[_][]const u8{ "does", "not", "exist", "foo.exe" });
    const output_arg = try std.fmt.allocPrint(a, "-femit-bin={s}", .{output_path});
    const source_path = try fs.path.join(a, &[_][]const u8{ "src", "main.zig" });
    const result = try exec(dir_path, false, &[_][]const u8{ zig_exe, "build-exe", source_path, output_arg });
    const s = std.fs.path.sep_str;
    const expected: []const u8 = "error: unable to open output directory 'does" ++ s ++ "not" ++ s ++ "exist': FileNotFound\n";
    testing.expectEqualStrings(expected, result.stderr);
}

fn testZigFmt(zig_exe: []const u8, dir_path: []const u8) !void {
    _ = try exec(dir_path, true, &[_][]const u8{ zig_exe, "init-exe" });

    const unformatted_code = "    // no reason for indent";

    const fmt1_zig_path = try fs.path.join(a, &[_][]const u8{ dir_path, "fmt1.zig" });
    try fs.cwd().writeFile(fmt1_zig_path, unformatted_code);

    const run_result1 = try exec(dir_path, true, &[_][]const u8{ zig_exe, "fmt", fmt1_zig_path });
    // stderr should be file path + \n
    testing.expect(std.mem.startsWith(u8, run_result1.stdout, fmt1_zig_path));
    testing.expect(run_result1.stdout.len == fmt1_zig_path.len + 1 and run_result1.stdout[run_result1.stdout.len - 1] == '\n');

    const fmt2_zig_path = try fs.path.join(a, &[_][]const u8{ dir_path, "fmt2.zig" });
    try fs.cwd().writeFile(fmt2_zig_path, unformatted_code);

    const run_result2 = try exec(dir_path, true, &[_][]const u8{ zig_exe, "fmt", dir_path });
    // running it on the dir, only the new file should be changed
    testing.expect(std.mem.startsWith(u8, run_result2.stdout, fmt2_zig_path));
    testing.expect(run_result2.stdout.len == fmt2_zig_path.len + 1 and run_result2.stdout[run_result2.stdout.len - 1] == '\n');

    const run_result3 = try exec(dir_path, true, &[_][]const u8{ zig_exe, "fmt", dir_path });
    // both files have been formatted, nothing should change now
    testing.expect(run_result3.stdout.len == 0);
}
