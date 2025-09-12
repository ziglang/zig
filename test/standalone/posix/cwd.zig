const std = @import("std");
const builtin = @import("builtin");

const path_max = std.fs.max_path_bytes;

pub fn main() !void {
    if (builtin.target.os.tag == .wasi) {
        // WASI doesn't support changing the working directory at all.
        return;
    }

    var Allocator = std.heap.DebugAllocator(.{}){};
    const a = Allocator.allocator();
    defer std.debug.assert(Allocator.deinit() == .ok);

    try test_chdir_self();
    try test_chdir_absolute();
    try test_chdir_relative(a);
}

// get current working directory and expect it to match given path
fn expect_cwd(expected_cwd: []const u8) !void {
    var cwd_buf: [path_max]u8 = undefined;
    const actual_cwd = try std.posix.getcwd(cwd_buf[0..]);
    try std.testing.expectEqualStrings(actual_cwd, expected_cwd);
}

fn test_chdir_self() !void {
    var old_cwd_buf: [path_max]u8 = undefined;
    const old_cwd = try std.posix.getcwd(old_cwd_buf[0..]);

    // Try changing to the current directory
    try std.posix.chdir(old_cwd);
    try expect_cwd(old_cwd);
}

fn test_chdir_absolute() !void {
    var old_cwd_buf: [path_max]u8 = undefined;
    const old_cwd = try std.posix.getcwd(old_cwd_buf[0..]);

    const parent = std.fs.path.dirname(old_cwd) orelse unreachable; // old_cwd should be absolute

    // Try changing to the parent via a full path
    try std.posix.chdir(parent);

    try expect_cwd(parent);
}

fn test_chdir_relative(a: std.mem.Allocator) !void {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Use the tmpDir parent_dir as the "base" for the test. Then cd into the child
    try tmp.parent_dir.setAsCwd();

    // Capture base working directory path, to build expected full path
    var base_cwd_buf: [path_max]u8 = undefined;
    const base_cwd = try std.posix.getcwd(base_cwd_buf[0..]);

    const relative_dir_name = &tmp.sub_path;
    const expected_path = try std.fs.path.resolve(a, &.{ base_cwd, relative_dir_name });
    defer a.free(expected_path);

    // change current working directory to new test directory
    try std.posix.chdir(relative_dir_name);

    var new_cwd_buf: [path_max]u8 = undefined;
    const new_cwd = try std.posix.getcwd(new_cwd_buf[0..]);

    // On Windows, fs.path.resolve returns an uppercase drive letter, but the drive letter returned by getcwd may be lowercase
    const resolved_cwd = try std.fs.path.resolve(a, &.{new_cwd});
    defer a.free(resolved_cwd);

    try std.testing.expectEqualStrings(expected_path, resolved_cwd);
}
