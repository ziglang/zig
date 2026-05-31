// Test relative paths through POSIX APIS.  These tests have to change the cwd, so
// they shouldn't be Zig unit tests.

const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    if (builtin.target.os.tag == .wasi) return; // Can link, but can't change into tmpDir

    var Allocator = std.heap.DebugAllocator(.{}){};
    const a = Allocator.allocator();
    defer std.debug.assert(Allocator.deinit() == .ok);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Want to test relative paths, so cd into the tmpdir for these tests
    try tmp.dir.setAsCwd();

    try test_symlink(a, tmp);
    try test_link(tmp);
}

fn test_symlink(a: std.mem.Allocator, tmp: std.testing.TmpDir) !void {
    const target_name = "symlink-target";
    const symlink_name = "symlinker";

    // Create the target file
    try tmp.dir.writeFile(.{ .sub_path = target_name, .data = "nonsense" });

    if (builtin.target.os.tag == .windows) {
        const wtarget_name = try std.unicode.wtf8ToWtf16LeAllocZ(a, target_name);
        const wsymlink_name = try std.unicode.wtf8ToWtf16LeAllocZ(a, symlink_name);
        defer a.free(wtarget_name);
        defer a.free(wsymlink_name);

        std.os.windows.CreateSymbolicLink(tmp.dir.fd, wsymlink_name, wtarget_name, false) catch |err| switch (err) {
            // Symlink requires admin privileges on windows, so this test can legitimately fail.
            error.AccessDenied => return,
            else => return err,
        };
    } else {
        try std.posix.symlink(target_name, symlink_name);
    }

    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const given = try std.posix.readlink(symlink_name, buffer[0..]);
    try std.testing.expectEqualStrings(target_name, given);
}

fn test_link(tmp: std.testing.TmpDir) !void {
    switch (builtin.target.os.tag) {
        .linux, .illumos => {},
        else => return,
    }

    if ((builtin.cpu.arch == .riscv32 or builtin.cpu.arch.isLoongArch()) and builtin.target.os.tag == .linux and !builtin.link_libc) {
        return; // No `fstat()`.
    }

    if (builtin.cpu.arch.isMIPS64()) {
        return; // `nstat.nlink` assertion is failing with LLVM 20+ for unclear reasons.
    }

    const target_name = "link-target";
    const link_name = "newlink";

    try tmp.dir.writeFile(.{ .sub_path = target_name, .data = "example" });

    // Test 1: create the relative link from inside tmp
    try std.posix.link(target_name, link_name);

    // Verify
    const efd = try tmp.dir.openFile(target_name, .{});
    defer efd.close();

    const nfd = try tmp.dir.openFile(link_name, .{});
    defer nfd.close();

    {
        const estat = try std.posix.fstat(efd.handle);
        const nstat = try std.posix.fstat(nfd.handle);
        try std.testing.expectEqual(estat.ino, nstat.ino);
        try std.testing.expectEqual(@as(@TypeOf(nstat.nlink), 2), nstat.nlink);
    }

    // Test 2: Remove the link and see the stats update
    try std.posix.unlink(link_name);

    {
        const estat = try std.posix.fstat(efd.handle);
        try std.testing.expectEqual(@as(@TypeOf(estat.nlink), 1), estat.nlink);
    }
}
