const std = @import("std");
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const warn = std.log.warn;
const fatal = std.process.fatal;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);

    const exe = args[0];
    var catted_anything = false;
    var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
    const stdout = &stdout_writer.interface;
    var stdin_reader = std.fs.File.stdin().reader(&.{});

    const cwd = fs.cwd();

    for (args[1..]) |arg| {
        if (mem.eql(u8, arg, "-")) {
            catted_anything = true;
            _ = try stdout.sendFileAll(&stdin_reader, .unlimited);
        } else if (mem.startsWith(u8, arg, "-")) {
            return usage(exe);
        } else {
            const file = cwd.openFile(arg, .{}) catch |err| fatal("unable to open file: {t}\n", .{err});
            defer file.close();

            catted_anything = true;
            var file_reader = file.reader(&.{});
            _ = try stdout.sendFileAll(&file_reader, .unlimited);
        }
    }
    if (!catted_anything) {
        _ = try stdout.sendFileAll(&stdin_reader, .unlimited);
    }
}

fn usage(exe: []const u8) !void {
    warn("Usage: {s} [FILE]...\n", .{exe});
    return error.Invalid;
}
