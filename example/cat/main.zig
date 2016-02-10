export executable "cat";

import "std.zig";

// Things to do to make this work:
// * var args printing
// * cast err type to string
// * string equality

pub fn main(args: [][]u8) -> %void {
    const exe = args[0];
    var catted_anything = false;
    for (arg, args[1...]) {
        if (arg == "-") {
            catted_anything = true;
            cat_stream(stdin) %% |err| return err;
        } else if (arg[0] == '-') {
            return usage(exe);
        } else {
            var is = input_stream_open(arg, OpenReadOnly) %% |err| {
                %%stderr.print("Unable to open file: {}", ([]u8)(err));
                return err;
            };
            defer is.close();

            catted_anything = true;
            cat_stream(is) %% |err| return err;
        }
    }
    if (!catted_anything) {
        cat_stream(stdin) %% |err| return err;
    }
}

fn usage(exe: []u8) -> %void {
    %%stderr.print("Usage: {} [FILE]...\n", exe);
    return error.Invalid;
}

fn cat_stream(is: InputStream) -> %void {
    var buf: [1024 * 4]u8 = undefined;

    while (true) {
        const bytes_read = is.read(buf) %% |err| {
            %%stderr.print("Unable to read from stream: {}", ([]u8)(err));
            return err;
        }

        if (bytes_read == 0) {
            break;
        }

        stdout.write(buf[0...bytes_read]) %% |err| {
            %%stderr.print("Unable to write to stdout: {}", ([]u8)(err));
            return err;
        }
    }
}
