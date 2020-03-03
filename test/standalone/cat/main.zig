const std = @import("std");
const io = std.io;
const process = std.process;
const fs = std.fs;
const mem = std.mem;
const warn = std.debug.warn;
const allocator = std.testing.allocator;

pub fn main() !void {
    var args_it = process.args();
    const exe = try unwrapArg(args_it.next(allocator).?);
    var catted_anything = false;
    const stdout_file = io.getStdOut();

    const cwd = fs.cwd();

    while (args_it.next(allocator)) |arg_or_err| {
        const arg = try unwrapArg(arg_or_err);
        if (mem.eql(u8, arg, "-")) {
            catted_anything = true;
            try cat_file(stdout_file, io.getStdIn());
        } else if (arg[0] == '-') {
            return usage(exe);
        } else {
            const file = cwd.openFile(arg, .{}) catch |err| {
                warn("Unable to open file: {}\n", .{@errorName(err)});
                return err;
            };
            defer file.close();

            catted_anything = true;
            try cat_file(stdout_file, file);
        }
    }
    if (!catted_anything) {
        try cat_file(stdout_file, io.getStdIn());
    }
}

fn usage(exe: []const u8) !void {
    warn("Usage: {} [FILE]...\n", .{exe});
    return error.Invalid;
}

// TODO use copy_file_range
fn cat_file(stdout: fs.File, file: fs.File) !void {
    var buf: [1024 * 4]u8 = undefined;

    while (true) {
        const bytes_read = file.read(buf[0..]) catch |err| {
            warn("Unable to read from stream: {}\n", .{@errorName(err)});
            return err;
        };

        if (bytes_read == 0) {
            break;
        }

        stdout.writeAll(buf[0..bytes_read]) catch |err| {
            warn("Unable to write to stdout: {}\n", .{@errorName(err)});
            return err;
        };
    }
}

fn unwrapArg(arg: anyerror![]u8) ![]u8 {
    return arg catch |err| {
        warn("Unable to parse command line: {}\n", .{err});
        return err;
    };
}
