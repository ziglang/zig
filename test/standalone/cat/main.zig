const std = @import("std");
const io = std.io;
const process = std.process;
const fs = std.fs;
const mem = std.mem;
const warn = std.log.warn;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try process.argsAlloc(arena);

    const exe = args[0];
    var catted_anything = false;
    const stdout_file = io.getStdOut();

    const cwd = fs.cwd();

    for (args[1..]) |arg| {
        if (mem.eql(u8, arg, "-")) {
            catted_anything = true;
            try stdout_file.writeFileAll(io.getStdIn(), .{});
        } else if (mem.startsWith(u8, arg, "-")) {
            return usage(exe);
        } else {
            const file = cwd.openFile(arg, .{}) catch |err| {
                warn("Unable to open file: {s}\n", .{@errorName(err)});
                return err;
            };
            defer file.close();

            catted_anything = true;
            try stdout_file.writeFileAll(file, .{});
        }
    }
    if (!catted_anything) {
        try stdout_file.writeFileAll(io.getStdIn(), .{});
    }
}

fn usage(exe: []const u8) !void {
    warn("Usage: {s} [FILE]...\n", .{exe});
    return error.Invalid;
}
