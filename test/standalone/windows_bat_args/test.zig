const std = @import("std");

pub fn main() anyerror!void {
    var debug_alloc_inst: std.heap.DebugAllocator(.{}) = .init;
    defer std.debug.assert(debug_alloc_inst.deinit() == .ok);
    const gpa = debug_alloc_inst.allocator();

    var it = try std.process.argsWithAllocator(gpa);
    defer it.deinit();
    _ = it.next() orelse unreachable; // skip binary name
    const child_exe_path_orig = it.next() orelse unreachable;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.setAsCwd();
    defer tmp.parent_dir.setAsCwd() catch {};

    // `child_exe_path_orig` might be relative; make it relative to our new cwd.
    const child_exe_path = try std.fs.path.resolve(gpa, &.{ "..\\..\\..", child_exe_path_orig });
    defer gpa.free(child_exe_path);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(gpa);
    try buf.print(gpa,
        \\@echo off
        \\"{s}"
    , .{child_exe_path});
    // Trailing newline intentionally omitted above so we can add args.
    const preamble_len = buf.items.len;

    try buf.appendSlice(gpa, " %*");
    try tmp.dir.writeFile(.{ .sub_path = "args1.bat", .data = buf.items });
    buf.shrinkRetainingCapacity(preamble_len);

    try buf.appendSlice(gpa, " %1 %2 %3 %4 %5 %6 %7 %8 %9");
    try tmp.dir.writeFile(.{ .sub_path = "args2.bat", .data = buf.items });
    buf.shrinkRetainingCapacity(preamble_len);

    try buf.appendSlice(gpa, " \"%~1\" \"%~2\" \"%~3\" \"%~4\" \"%~5\" \"%~6\" \"%~7\" \"%~8\" \"%~9\"");
    try tmp.dir.writeFile(.{ .sub_path = "args3.bat", .data = buf.items });
    buf.shrinkRetainingCapacity(preamble_len);

    // Test cases are from https://github.com/rust-lang/rust/blob/master/tests/ui/std/windows-bat-args.rs
    try testExecError(error.InvalidBatchScriptArg, gpa, &.{"\x00"});
    try testExecError(error.InvalidBatchScriptArg, gpa, &.{"\n"});
    try testExecError(error.InvalidBatchScriptArg, gpa, &.{"\r"});
    try testExec(gpa, &.{ "a", "b" }, null);
    try testExec(gpa, &.{ "c is for cat", "d is for dog" }, null);
    try testExec(gpa, &.{ "\"", " \"" }, null);
    try testExec(gpa, &.{ "\\", "\\" }, null);
    try testExec(gpa, &.{">file.txt"}, null);
    try testExec(gpa, &.{"whoami.exe"}, null);
    try testExec(gpa, &.{"&a.exe"}, null);
    try testExec(gpa, &.{"&echo hello "}, null);
    try testExec(gpa, &.{ "&echo hello", "&whoami", ">file.txt" }, null);
    try testExec(gpa, &.{"!TMP!"}, null);
    try testExec(gpa, &.{"key=value"}, null);
    try testExec(gpa, &.{"\"key=value\""}, null);
    try testExec(gpa, &.{"key = value"}, null);
    try testExec(gpa, &.{"key=[\"value\"]"}, null);
    try testExec(gpa, &.{ "", "a=b" }, null);
    try testExec(gpa, &.{"key=\"foo bar\""}, null);
    try testExec(gpa, &.{"key=[\"my_value]"}, null);
    try testExec(gpa, &.{"key=[\"my_value\",\"other-value\"]"}, null);
    try testExec(gpa, &.{"key\\=value"}, null);
    try testExec(gpa, &.{"key=\"&whoami\""}, null);
    try testExec(gpa, &.{"key=\"value\"=5"}, null);
    try testExec(gpa, &.{"key=[\">file.txt\"]"}, null);
    try testExec(gpa, &.{"%hello"}, null);
    try testExec(gpa, &.{"%PATH%"}, null);
    try testExec(gpa, &.{"%%cd:~,%"}, null);
    try testExec(gpa, &.{"%PATH%PATH%"}, null);
    try testExec(gpa, &.{"\">file.txt"}, null);
    try testExec(gpa, &.{"abc\"&echo hello"}, null);
    try testExec(gpa, &.{"123\">file.txt"}, null);
    try testExec(gpa, &.{"\"&echo hello&whoami.exe"}, null);
    try testExec(gpa, &.{ "\"hello^\"world\"", "hello &echo oh no >file.txt" }, null);
    try testExec(gpa, &.{"&whoami.exe"}, null);

    // Ensure that trailing space and . characters can't lead to unexpected bat/cmd script execution.
    // In many Windows APIs (including CreateProcess), trailing space and . characters are stripped
    // from paths, so if a path with trailing . and space character(s) is passed directly to
    // CreateProcess, then it could end up executing a batch/cmd script that naive extension detection
    // would not flag as .bat/.cmd.
    //
    // Note that we expect an error here, though, which *is* a valid mitigation, but also an implementation detail.
    // This error is caused by the use of a wildcard with NtQueryDirectoryFile to optimize PATHEXT searching. That is,
    // the trailing characters in the app name will lead to a FileNotFound error as the wildcard-appended path will not
    // match any real paths on the filesystem (e.g. `foo.bat .. *` will not match `foo.bat`; only `foo.bat*` will).
    //
    // This being an error matches the behavior of running a command via the command line of cmd.exe, too:
    //
    //     > "args1.bat .. "
    //     '"args1.bat .. "' is not recognized as an internal or external command,
    //     operable program or batch file.
    try std.testing.expectError(error.FileNotFound, testExecBat(gpa, "args1.bat .. ", &.{"abc"}, null));
    const absolute_with_trailing = blk: {
        const absolute_path = try std.fs.realpathAlloc(gpa, "args1.bat");
        defer gpa.free(absolute_path);
        break :blk try std.mem.concat(gpa, u8, &.{ absolute_path, " .. " });
    };
    defer gpa.free(absolute_with_trailing);
    try std.testing.expectError(error.FileNotFound, testExecBat(gpa, absolute_with_trailing, &.{"abc"}, null));

    var env = env: {
        var env = try std.process.getEnvMap(gpa);
        errdefer env.deinit();
        // No escaping
        try env.put("FOO", "123");
        // Some possible escaping of %FOO% that could be expanded
        // when escaping cmd.exe meta characters with ^
        try env.put("FOO^", "123"); // only escaping %
        try env.put("^F^O^O^", "123"); // escaping every char
        break :env env;
    };
    defer env.deinit();
    try testExec(gpa, &.{"%FOO%"}, &env);

    // Ensure that none of the `>file.txt`s have caused file.txt to be created
    try std.testing.expectError(error.FileNotFound, tmp.dir.access("file.txt", .{}));
}

fn testExecError(err: anyerror, gpa: std.mem.Allocator, args: []const []const u8) !void {
    return std.testing.expectError(err, testExec(gpa, args, null));
}

fn testExec(gpa: std.mem.Allocator, args: []const []const u8, env: ?*std.process.EnvMap) !void {
    try testExecBat(gpa, "args1.bat", args, env);
    try testExecBat(gpa, "args2.bat", args, env);
    try testExecBat(gpa, "args3.bat", args, env);
}

fn testExecBat(gpa: std.mem.Allocator, bat: []const u8, args: []const []const u8, env: ?*std.process.EnvMap) !void {
    const argv = try gpa.alloc([]const u8, 1 + args.len);
    defer gpa.free(argv);
    argv[0] = bat;
    @memcpy(argv[1..], args);

    const can_have_trailing_empty_args = std.mem.eql(u8, bat, "args3.bat");

    const result = try std.process.Child.run(.{
        .allocator = gpa,
        .env_map = env,
        .argv = argv,
    });
    defer gpa.free(result.stdout);
    defer gpa.free(result.stderr);

    try std.testing.expectEqualStrings("", result.stderr);
    var it = std.mem.splitScalar(u8, result.stdout, '\x00');
    var i: usize = 0;
    while (it.next()) |actual_arg| {
        if (i >= args.len and can_have_trailing_empty_args) {
            try std.testing.expectEqualStrings("", actual_arg);
            continue;
        }
        const expected_arg = args[i];
        try std.testing.expectEqualStrings(expected_arg, actual_arg);
        i += 1;
    }
}
