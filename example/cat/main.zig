const std = @import("std");
const io = std.io;
const str = std.str;

// TODO var args printing

pub fn main(args: [][]u8) -> %void {
    const exe = args[0];
    var catted_anything = false;
    for (args[1...]) |arg| {
        if (str.eql(arg, "-")) {
            catted_anything = true;
            cat_stream(io.stdin) %% |err| return err;
        } else if (arg[0] == '-') {
            return usage(exe);
        } else {
            var is: io.InStream = undefined;
            is.open(arg) %% |err| {
                %%io.stderr.printf("Unable to open file: ");
                %%io.stderr.printf(@errName(err));
                %%io.stderr.printf("\n");
                return err;
            };
            defer %%is.close();

            catted_anything = true;
            cat_stream(is) %% |err| return err;
        }
    }
    if (!catted_anything) {
        cat_stream(io.stdin) %% |err| return err;
    }
    io.stdout.flush() %% |err| return err;
}

fn usage(exe: []u8) -> %void {
    %%io.stderr.printf("Usage: ");
    %%io.stderr.printf(exe);
    %%io.stderr.printf(" [FILE]...\n");
    return error.Invalid;
}

fn cat_stream(is: io.InStream) -> %void {
    var buf: [1024 * 4]u8 = undefined;

    while (true) {
        const bytes_read = is.read(buf) %% |err| {
            %%io.stderr.printf("Unable to read from stream: ");
            %%io.stderr.printf(@errName(err));
            %%io.stderr.printf("\n");
            return err;
        };

        if (bytes_read == 0) {
            break;
        }

        io.stdout.write(buf[0...bytes_read]) %% |err| {
            %%io.stderr.printf("Unable to write to stdout: ");
            %%io.stderr.printf(@errName(err));
            %%io.stderr.printf("\n");
            return err;
        };
    }
}
