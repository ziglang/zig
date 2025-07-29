//! This script updates the .c, .h, .s, and .S files that make up the start
//! files such as crt1.o.
//!
//! Example usage:
//! `zig run tools/update_netbsd_libc.zig -- ~/Downloads/netbsd-src .`

const std = @import("std");

const exempt_files = [_][]const u8{
    // This file is maintained by a separate project and does not come from NetBSD.
    "abilists",
};

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const netbsd_src_path = args[1];
    const zig_src_path = args[2];

    const dest_dir_path = try std.fmt.allocPrint(arena, "{s}/lib/libc/netbsd", .{zig_src_path});

    var dest_dir = std.fs.cwd().openDir(dest_dir_path, .{ .iterate = true }) catch |err| {
        std.log.err("unable to open destination directory '{s}': {s}", .{
            dest_dir_path, @errorName(err),
        });
        std.process.exit(1);
    };
    defer dest_dir.close();

    var netbsd_src_dir = try std.fs.cwd().openDir(netbsd_src_path, .{});
    defer netbsd_src_dir.close();

    // Copy updated files from upstream.
    {
        var walker = try dest_dir.walk(arena);
        defer walker.deinit();

        walk: while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (std.mem.startsWith(u8, entry.basename, ".")) continue;
            for (exempt_files) |p| {
                if (std.mem.eql(u8, entry.path, p)) continue :walk;
            }

            std.log.info("updating '{s}/{s}' from '{s}/{s}'", .{
                dest_dir_path,   entry.path,
                netbsd_src_path, entry.path,
            });

            netbsd_src_dir.copyFile(entry.path, dest_dir, entry.path, .{}) catch |err| {
                std.log.warn("unable to copy '{s}/{s}' to '{s}/{s}': {s}", .{
                    netbsd_src_path, entry.path,
                    dest_dir_path,   entry.path,
                    @errorName(err),
                });
                if (err == error.FileNotFound) {
                    try dest_dir.deleteFile(entry.path);
                }
            };
        }
    }
}
