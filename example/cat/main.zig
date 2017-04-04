const std = @import("std");
const io = std.io;
const mem = std.mem;
const os = std.os;

pub fn main() -> %void {
    const exe = os.args.at(0);
    var catted_anything = false;
    var arg_i: usize = 1;
    while (arg_i < os.args.count(); arg_i += 1) {
        const arg = os.args.at(arg_i);
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
        const bytes_read = is.read(buf[0...]) %% |err| {
            %%io.stderr.printf("Unable to read from stream: {}\n", @errorName(err));
            return err;
        };

        if (bytes_read == 0) {
            break;
        }

        io.stdout.write(buf[0...bytes_read]) %% |err| {
            %%io.stderr.printf("Unable to write to stdout: {}\n", @errorName(err));
            return err;
        };
    }
}
