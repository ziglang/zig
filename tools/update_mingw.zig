const std = @import("std");

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const zig_src_lib_path = args[1];
    const mingw_src_path = args[2];

    if (std.mem.eql(u8, mingw_src_path, "--missing-mingw-source-directory")) {
        std.log.err("this build step requires passing -Dmingw-src=[path]", .{});
        std.process.exit(1);
    }

    const dest_mingw_crt_path = try std.fs.path.join(arena, &.{
        zig_src_lib_path, "libc", "mingw",
    });
    const src_mingw_crt_path = try std.fs.path.join(arena, &.{
        mingw_src_path, "mingw-w64-crt",
    });

    // Update only the set of existing files we have already chosen to include
    // in zig's installation.

    var dest_crt_dir = std.fs.cwd().openDir(dest_mingw_crt_path, .{ .iterate = true }) catch |err| {
        std.log.err("unable to open directory '{s}': {s}", .{ dest_mingw_crt_path, @errorName(err) });
        std.process.exit(1);
    };
    defer dest_crt_dir.close();

    var src_crt_dir = std.fs.cwd().openDir(src_mingw_crt_path, .{ .iterate = true }) catch |err| {
        std.log.err("unable to open directory '{s}': {s}", .{ src_mingw_crt_path, @errorName(err) });
        std.process.exit(1);
    };
    defer src_crt_dir.close();

    {
        var walker = try dest_crt_dir.walk(arena);
        defer walker.deinit();

        var fail = false;

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;

            src_crt_dir.copyFile(entry.path, dest_crt_dir, entry.path, .{}) catch |err| switch (err) {
                error.FileNotFound => {
                    const whitelisted = for (whitelist) |item| {
                        if (std.mem.eql(u8, entry.path, item)) break true;
                    } else false;

                    if (!whitelisted) {
                        std.log.warn("deleting {s}", .{entry.path});
                        try dest_crt_dir.deleteFile(entry.path);
                    }
                },
                else => {
                    std.log.err("unable to copy {s}: {s}", .{ entry.path, @errorName(err) });
                    fail = true;
                },
            };
        }

        if (fail) std.process.exit(1);
    }

    {
        // Also add all new def and def.in files.
        var walker = try src_crt_dir.walk(arena);
        defer walker.deinit();

        var fail = false;

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;

            const ok_ext = for (ok_exts) |ext| {
                if (std.mem.endsWith(u8, entry.path, ext)) break true;
            } else false;

            if (!ok_ext) continue;

            const ok_prefix = for (ok_prefixes) |p| {
                if (std.mem.startsWith(u8, entry.path, p)) break true;
            } else false;

            if (!ok_prefix) continue;

            const blacklisted = for (blacklist) |item| {
                if (std.mem.eql(u8, entry.basename, item)) break true;
            } else false;

            if (blacklisted) continue;

            if (std.mem.endsWith(u8, entry.basename, "_windowsapp.def"))
                continue;

            if (std.mem.endsWith(u8, entry.basename, "_onecore.def"))
                continue;

            src_crt_dir.copyFile(entry.path, dest_crt_dir, entry.path, .{}) catch |err| {
                std.log.err("unable to copy {s}: {s}", .{ entry.path, @errorName(err) });
                fail = true;
            };
        }
        if (fail) std.process.exit(1);
    }

    return std.process.cleanExit();
}

const whitelist = [_][]const u8{
    "COPYING",
    "include" ++ std.fs.path.sep_str ++ "config.h",
};

const ok_exts = [_][]const u8{
    ".def",
    ".def.in",
};

const ok_prefixes = [_][]const u8{
    "lib32" ++ std.fs.path.sep_str,
    "lib64" ++ std.fs.path.sep_str,
    "libarm32" ++ std.fs.path.sep_str,
    "libarm64" ++ std.fs.path.sep_str,
    "lib-common" ++ std.fs.path.sep_str,
    "def-include" ++ std.fs.path.sep_str,
};

const blacklist = [_][]const u8{
    "msvcp60.def",
    "msvcp120_app.def.in",
    "msvcp60.def",
    "msvcp120_clr0400.def",
    "msvcp110.def",
    "msvcp60.def",
    "msvcp120_app.def.in",

    "msvcr100.def.in",
    "msvcr110.def",
    "msvcr110.def.in",
    "msvcr120.def.in",
    "msvcr120_app.def.in",
    "msvcr120_clr0400.def",
    "msvcr120d.def.in",
    "msvcr70.def.in",
    "msvcr71.def.in",
    "msvcr80.def.in",
    "msvcr90.def.in",
    "msvcr90d.def.in",
    "msvcrt.def.in",
    "msvcrt10.def.in",
    "msvcrt20.def.in",
    "msvcrt40.def.in",

    "crtdll.def.in",
};
