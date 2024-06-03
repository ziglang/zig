const std = @import("std");
const windows = std.os.windows;
const utf16Literal = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("found memory leaks");
    const allocator = gpa.allocator();

    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();
    _ = it.next() orelse unreachable; // skip binary name
    const hello_exe_cache_path = it.next() orelse unreachable;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const tmp_absolute_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(tmp_absolute_path);
    const tmp_absolute_path_w = try std.unicode.utf8ToUtf16LeAllocZ(allocator, tmp_absolute_path);
    defer allocator.free(tmp_absolute_path_w);
    const cwd_absolute_path = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd_absolute_path);
    const tmp_relative_path = try std.fs.path.relative(allocator, cwd_absolute_path, tmp_absolute_path);
    defer allocator.free(tmp_relative_path);

    // Clear PATH
    std.debug.assert(windows.kernel32.SetEnvironmentVariableW(
        utf16Literal("PATH"),
        null,
    ) == windows.TRUE);

    // Set PATHEXT to something predictable
    std.debug.assert(windows.kernel32.SetEnvironmentVariableW(
        utf16Literal("PATHEXT"),
        utf16Literal(".COM;.EXE;.BAT;.CMD;.JS"),
    ) == windows.TRUE);

    // No PATH, so it should fail to find anything not in the cwd
    try testExecError(error.FileNotFound, allocator, "something_missing");

    std.debug.assert(windows.kernel32.SetEnvironmentVariableW(
        utf16Literal("PATH"),
        tmp_absolute_path_w,
    ) == windows.TRUE);

    // Move hello.exe into the tmp dir which is now added to the path
    try std.fs.cwd().copyFile(hello_exe_cache_path, tmp.dir, "hello.exe", .{});

    // with extension should find the .exe (case insensitive)
    try testExec(allocator, "HeLLo.exe", "hello from exe\n");
    // without extension should find the .exe (case insensitive)
    try testExec(allocator, "heLLo", "hello from exe\n");

    // now add a .bat
    try tmp.dir.writeFile(.{ .sub_path = "hello.bat", .data = "@echo hello from bat" });
    // and a .cmd
    try tmp.dir.writeFile(.{ .sub_path = "hello.cmd", .data = "@echo hello from cmd" });

    // with extension should find the .bat (case insensitive)
    try testExec(allocator, "heLLo.bat", "hello from bat\r\n");
    // with extension should find the .cmd (case insensitive)
    try testExec(allocator, "heLLo.cmd", "hello from cmd\r\n");
    // without extension should find the .exe (since its first in PATHEXT)
    try testExec(allocator, "heLLo", "hello from exe\n");

    // now rename the exe to not have an extension
    try tmp.dir.rename("hello.exe", "hello");

    // with extension should now fail
    try testExecError(error.FileNotFound, allocator, "hello.exe");
    // without extension should succeed (case insensitive)
    try testExec(allocator, "heLLo", "hello from exe\n");

    try tmp.dir.makeDir("something");
    try tmp.dir.rename("hello", "something/hello.exe");

    const relative_path_no_ext = try std.fs.path.join(allocator, &.{ tmp_relative_path, "something/hello" });
    defer allocator.free(relative_path_no_ext);

    // Giving a full relative path to something/hello should work
    try testExec(allocator, relative_path_no_ext, "hello from exe\n");
    // But commands with path separators get excluded from PATH searching, so this will fail
    try testExecError(error.FileNotFound, allocator, "something/hello");

    // Now that .BAT is the first PATHEXT that should be found, this should succeed
    try testExec(allocator, "heLLo", "hello from bat\r\n");

    // Add a hello.exe that is not a valid executable
    try tmp.dir.writeFile(.{ .sub_path = "hello.exe", .data = "invalid" });

    // Trying to execute it with extension will give InvalidExe. This is a special
    // case for .EXE extensions, where if they ever try to get executed but they are
    // invalid, that gets treated as a fatal error wherever they are found and InvalidExe
    // is returned immediately.
    try testExecError(error.InvalidExe, allocator, "hello.exe");
    // Same thing applies to the command with no extension--even though there is a
    // hello.bat that could be executed, it should stop after it tries executing
    // hello.exe and getting InvalidExe.
    try testExecError(error.InvalidExe, allocator, "hello");

    // If we now rename hello.exe to have no extension, it will behave differently
    try tmp.dir.rename("hello.exe", "hello");

    // Now, trying to execute it without an extension should treat InvalidExe as recoverable
    // and skip over it and find hello.bat and execute that
    try testExec(allocator, "hello", "hello from bat\r\n");

    // If we rename the invalid exe to something else
    try tmp.dir.rename("hello", "goodbye");
    // Then we should now get FileNotFound when trying to execute 'goodbye',
    // since that is what the original error will be after searching for 'goodbye'
    // in the cwd. It will try to execute 'goodbye' from the PATH but the InvalidExe error
    // should be ignored in this case.
    try testExecError(error.FileNotFound, allocator, "goodbye");

    // Now let's set the tmp dir as the cwd and set the path only include the "something" sub dir
    try tmp.dir.setAsCwd();
    defer tmp.parent_dir.setAsCwd() catch {};
    const something_subdir_abs_path = try std.mem.concatWithSentinel(allocator, u16, &.{ tmp_absolute_path_w, utf16Literal("\\something") }, 0);
    defer allocator.free(something_subdir_abs_path);

    std.debug.assert(windows.kernel32.SetEnvironmentVariableW(
        utf16Literal("PATH"),
        something_subdir_abs_path,
    ) == windows.TRUE);

    // Now trying to execute goodbye should give error.InvalidExe since it's the original
    // error that we got when trying within the cwd
    try testExecError(error.InvalidExe, allocator, "goodbye");

    // hello should still find the .bat
    try testExec(allocator, "hello", "hello from bat\r\n");

    // If we rename something/hello.exe to something/goodbye.exe
    try tmp.dir.rename("something/hello.exe", "something/goodbye.exe");
    // And try to execute goodbye, then the one in something should be found
    // since the one in cwd is an invalid executable
    try testExec(allocator, "goodbye", "hello from exe\n");

    // If we use an absolute path to execute the invalid goodbye
    const goodbye_abs_path = try std.mem.join(allocator, "\\", &.{ tmp_absolute_path, "goodbye" });
    defer allocator.free(goodbye_abs_path);
    // then the PATH should not be searched and we should get InvalidExe
    try testExecError(error.InvalidExe, allocator, goodbye_abs_path);

    // If we try to exec but provide a cwd that is an absolute path, the PATH
    // should still be searched and the goodbye.exe in something should be found.
    try testExecWithCwd(allocator, "goodbye", tmp_absolute_path, "hello from exe\n");
}

fn testExecError(err: anyerror, allocator: std.mem.Allocator, command: []const u8) !void {
    return std.testing.expectError(err, testExec(allocator, command, ""));
}

fn testExec(allocator: std.mem.Allocator, command: []const u8, expected_stdout: []const u8) !void {
    return testExecWithCwd(allocator, command, null, expected_stdout);
}

fn testExecWithCwd(allocator: std.mem.Allocator, command: []const u8, cwd: ?[]const u8, expected_stdout: []const u8) !void {
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{command},
        .cwd = cwd,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try std.testing.expectEqualStrings("", result.stderr);
    try std.testing.expectEqualStrings(expected_stdout, result.stdout);
}
