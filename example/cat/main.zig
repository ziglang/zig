const std = @import("std");
const io = std.io;
const mem = std.mem;
const os = std.os;
const warn = std.debug.warn;

pub fn main() -> %void {
    const allocator = &std.debug.global_allocator;
    var args_it = os.args();
    const exe = %return unwrapArg(??args_it.next(allocator));
    var catted_anything = false;
    var stdout_file = %return io.getStdOut();

    while (args_it.next(allocator)) |arg_or_err| {
        const arg = %return unwrapArg(arg_or_err);
        if (mem.eql(u8, arg, "-")) {
            catted_anything = true;
            var stdin_file = %return io.getStdIn();
            %return cat_file(&stdout_file, &stdin_file);
        } else if (arg[0] == '-') {
            return usage(exe);
        } else {
            var file = io.File.openRead(arg, null) %% |err| {
                warn("Unable to open file: {}\n", @errorName(err));
                return err;
            };
            defer file.close();

            catted_anything = true;
            %return cat_file(&stdout_file, &file);
        }
    }
    if (!catted_anything) {
        var stdin_file = %return io.getStdIn();
        %return cat_file(&stdout_file, &stdin_file);
    }
}

fn usage(exe: []const u8) -> %void {
    warn("Usage: {} [FILE]...\n", exe);
    return error.Invalid;
}

fn cat_file(stdout: &io.File, file: &io.File) -> %void {
    var buf: [1024 * 4]u8 = undefined;

    while (true) {
        const bytes_read = file.read(buf[0..]) %% |err| {
            warn("Unable to read from stream: {}\n", @errorName(err));
            return err;
        };

        if (bytes_read == 0) {
            break;
        }

        stdout.write(buf[0..bytes_read]) %% |err| {
            warn("Unable to write to stdout: {}\n", @errorName(err));
            return err;
        };
    }
}

fn unwrapArg(arg: %[]u8) -> %[]u8 {
    return arg %% |err| {
        warn("Unable to parse command line: {}\n", err);
        return err;
    };
}
