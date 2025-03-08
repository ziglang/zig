const builtin = @import("builtin");
const std = @import("std");

pub fn build(b: *std.Build) !void {
    const fs_case_sensitive = try isFilesystemCaseSensitive(b.build_root);
    switch (builtin.os.tag) {
        .windows, .macos => try std.testing.expectEqual(false, fs_case_sensitive),
        else => {},
    }
    addCase(b, fs_case_sensitive, .import, .good);
    addCase(b, fs_case_sensitive, .import, .bad);
    addCase(b, fs_case_sensitive, .embed, .good);
    addCase(b, fs_case_sensitive, .embed, .bad);
}

fn addCase(
    b: *std.Build,
    fs_case_sensitive: bool,
    comptime kind: enum { import, embed },
    comptime variant: enum { good, bad },
) void {
    const name = @tagName(kind) ++ @tagName(variant);
    const compile = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "build-exe",
        "-fno-emit-bin",
        name ++ ".zig",
    });
    if (variant == .bad) {
        if (fs_case_sensitive) {
            switch (kind) {
                .import => compile.addCheck(.{ .expect_stderr_match = "unable to load" }),
                .embed => compile.addCheck(.{ .expect_stderr_match = "unable to open" }),
            }
            compile.addCheck(.{ .expect_stderr_match = "Foo.zig" });
            compile.addCheck(.{ .expect_stderr_match = "FileNotFound" });
        } else {
            compile.addCheck(.{
                .expect_stderr_match = b.fmt("{s} string 'Foo.zig' case does not match the filename", .{@tagName(kind)}),
            });
        }
    }
    b.default_step.dependOn(&compile.step);
}

fn isFilesystemCaseSensitive(test_dir: std.Build.Cache.Directory) !bool {
    const name_lower = "case-sensitivity-test-file";
    const name_upper = "CASE-SENSITIVITY-TEST-FILE";

    test_dir.handle.deleteFile(name_lower) catch |err| switch (err) {
        error.FileNotFound => {},
        else => |e| return e,
    };
    test_dir.handle.deleteFile(name_upper) catch |err| switch (err) {
        error.FileNotFound => {},
        else => |e| return e,
    };

    {
        const file = try test_dir.handle.createFile(name_lower, .{});
        file.close();
    }
    defer test_dir.handle.deleteFile(name_lower) catch |err| std.debug.panic(
        "failed to delete test file '{s}' in directory '{}' with {s}\n",
        .{ name_lower, test_dir, @errorName(err) },
    );
    {
        const file = test_dir.handle.openFile(name_upper, .{}) catch |err| switch (err) {
            error.FileNotFound => return true,
            else => |e| return e,
        };
        file.close();
    }
    return false;
}
