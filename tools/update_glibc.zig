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
    // This file is maintained by a separate project and does not come from glibc.
    "abilists",

    // Generated files.
    "include/libc-modules.h",
    "include/config.h",

    // These are easier to maintain like this, without updating to the abi-note.c
    // that glibc did upstream.
    "csu/abi-tag.h",
    "csu/abi-note.S",

    // We have patched these files to require fewer includes.
    "stdlib/at_quick_exit.c",
    "stdlib/atexit.c",
    "sysdeps/pthread/pthread_atfork.c",
};

const exempt_extensions = [_][]const u8{
    // These are the start files we use when targeting glibc <= 2.33.
    "-2.33.S",
    "-2.33.c",
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

    // Copy updated files from upstream.
    {
        var walker = try dest_dir.walk(arena);
        defer walker.deinit();

        walk: while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (mem.startsWith(u8, entry.basename, ".")) continue;
            for (exempt_files) |p| {
                if (mem.eql(u8, entry.path, p)) continue :walk;
            }
            for (exempt_extensions) |ext| {
                if (mem.endsWith(u8, entry.path, ext)) continue :walk;
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

    // Warn about duplicated files inside glibc/include/* that can be omitted
    // because they are already in generic-glibc/*.

    var include_dir = dest_dir.openDir("include", .{ .iterate = true }) catch |err| {
        fatal("unable to open directory '{s}/include': {s}", .{
            dest_dir_path, @errorName(err),
        });
    };
    defer include_dir.close();

    const generic_glibc_path = try std.fmt.allocPrint(
        arena,
        "{s}/lib/libc/include/generic-glibc",
        .{zig_src_path},
    );
    var generic_glibc_dir = try fs.cwd().openDir(generic_glibc_path, .{});
    defer generic_glibc_dir.close();

    var walker = try include_dir.walk(arena);
    defer walker.deinit();

    walk: while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (mem.startsWith(u8, entry.basename, ".")) continue;
        for (exempt_files) |p| {
            if (mem.eql(u8, entry.path, p)) continue :walk;
        }

        const max_file_size = 10 * 1024 * 1024;

        const generic_glibc_contents = generic_glibc_dir.readFileAlloc(
            arena,
            entry.path,
            max_file_size,
        ) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| fatal("unable to load '{s}/include/{s}': {s}", .{
                generic_glibc_path, entry.path, @errorName(e),
            }),
        };
        const glibc_include_contents = include_dir.readFileAlloc(
            arena,
            entry.path,
            max_file_size,
        ) catch |err| {
            fatal("unable to load '{s}/include/{s}': {s}", .{
                dest_dir_path, entry.path, @errorName(err),
            });
        };

        const whitespace = " \r\n\t";
        const generic_glibc_trimmed = mem.trim(u8, generic_glibc_contents, whitespace);
        const glibc_include_trimmed = mem.trim(u8, glibc_include_contents, whitespace);
        if (mem.eql(u8, generic_glibc_trimmed, glibc_include_trimmed)) {
            log.warn("same contents: '{s}/include/{s}' and '{s}/include/{s}'", .{
                generic_glibc_path, entry.path,
                dest_dir_path,      entry.path,
            });
        }
    }
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    log.err(format, args);
    std.process.exit(1);
}
