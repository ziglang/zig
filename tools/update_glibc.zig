//! This script updates the .c, .h, .s, and .S files that make up the start
//! files such as crt1.o. Not to be confused with
//! https://github.com/ziglang/glibc-abi-tool/ which updates the `abilists`
//! file.
//!
//! Example usage:
//! `zig run ../tools/update_glibc.zig -- ~/Downloads/glibc ..`

const std = @import("std");
const mem = std.mem;
const log = std.log;
const fs = std.fs;

const exempt_files = [_][]const u8{
    "abilists",
    "include/libc-modules.h",
    "include/config.h",
    // These are easier to maintain like this, without updating to the abi-note.c
    // that glibc did upstream.
    "csu/abi-tag.h",
    "csu/abi-note.S",
};

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const glibc_src_path = args[1];
    const zig_src_path = args[2];

    const dest_dir_path = try std.fmt.allocPrint(arena, "{s}/lib/libc/glibc", .{zig_src_path});

    var dest_dir = fs.cwd().openDir(dest_dir_path, .{ .iterate = true }) catch |err| {
        fatal("unable to open destination directory '{s}': {s}", .{
            dest_dir_path, @errorName(err),
        });
    };
    defer dest_dir.close();

    var glibc_src_dir = try fs.cwd().openDir(glibc_src_path, .{});
    defer glibc_src_dir.close();

    var walker = try dest_dir.walk(arena);
    defer walker.deinit();

    walk: while (try walker.next()) |entry| {
        if (entry.kind != .File) continue;
        if (mem.startsWith(u8, entry.basename, ".")) continue;
        for (exempt_files) |p| {
            if (mem.eql(u8, entry.path, p)) continue :walk;
        }

        glibc_src_dir.copyFile(entry.path, dest_dir, entry.path, .{}) catch |err| {
            log.warn("unable to copy '{s}/{s}' to '{s}/{s}': {s}", .{
                glibc_src_path,  entry.path,
                dest_dir_path,   entry.path,
                @errorName(err),
            });
            if (err == error.FileNotFound) {
                try dest_dir.deleteFile(entry.path);
            }
        };
    }
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    std.process.exit(1);
}
