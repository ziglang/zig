const std = @import("std");
const io = std.io;
const mem = std.mem;
const os = std.os;

pub fn main() -> %void {
    const allocator = &std.debug.global_allocator;
    var args_it = os.args();
    const exe = %return unwrapArg(??args_it.next(allocator));
    var catted_anything = false;
    while (args_it.next(allocator)) |arg_or_err| {
        const arg = %return unwrapArg(arg_or_err);
        if (mem.eql(u8, arg, "-")) {
            catted_anything = true;
            %return cat_stream(&io.stdin);
        } else if (arg[0] == '-') {
            return usage(exe);
        } else {
            var is = io.InStream.open(arg, null) %% |err| {
                %%io.stderr.printf("Unable to open file: {}\n", @errorName(err));
                return err;
            };
            defer is.close();

            catted_anything = true;
            %return cat_stream(&is);
        }
    }
    if (!catted_anything) {
        %return cat_stream(&io.stdin);
    }
    %return io.stdout.flush();
}

fn usage(exe: []const u8) -> %void {
    %%io.stderr.printf("Usage: {} [FILE]...\n", exe);
    return error.Invalid;
}

fn cat_stream(is: &io.InStream) -> %void {
    var buf: [1024 * 4]u8 = undefined;

    while (true) {
        const bytes_read = is.read(buf[0..]) %% |err| {
            %%io.stderr.printf("Unable to read from stream: {}\n", @errorName(err));
            return err;
        };

        if (bytes_read == 0) {
            break;
        }

        io.stdout.write(buf[0..bytes_read]) %% |err| {
            %%io.stderr.printf("Unable to write to stdout: {}\n", @errorName(err));
            return err;
        };
    }
}

fn unwrapArg(arg: %[]u8) -> %[]u8 {
    return arg %% |err| {
        %%io.stderr.printf("Unable to parse command line: {}\n", err);
        return err;
    };
}
