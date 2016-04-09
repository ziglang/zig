use @import("std");

// TODO var args printing

pub fn main(args: [][]u8) -> %void {
    const exe = args[0];
    var catted_anything = false;
    for (args[1...]) |arg| {
        if (str_eql(arg, "-")) {
            catted_anything = true;
            cat_stream(io.stdin) %% |err| return err;
        } else if (arg[0] == '-') {
            return usage(exe);
        } else {
            var is = io.InStream.open(arg) %% |err| {
                %%io.stderr.write("Unable to open file: ");
                %%io.stderr.write(@err_name(err));
                %%io.stderr.write("\n");
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
    %%io.stderr.write("Usage: ");
    %%io.stderr.write(exe);
    %%io.stderr.write(" [FILE]...\n");
    return error.Invalid;
}

fn cat_stream(is: io.InStream) -> %void {
    var buf: [1024 * 4]u8 = undefined;

    while (true) {
        const bytes_read = is.read(buf) %% |err| {
            %%io.stderr.write("Unable to read from stream: ");
            %%io.stderr.write(@err_name(err));
            %%io.stderr.write("\n");
            return err;
        };

        if (bytes_read == 0) {
            break;
        }

        io.stdout.write(buf[0...bytes_read]) %% |err| {
            %%io.stderr.write("Unable to write to stdout: ");
            %%io.stderr.write(@err_name(err));
            %%io.stderr.write("\n");
            return err;
        };
    }
}
