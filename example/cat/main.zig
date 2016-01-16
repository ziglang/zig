export executable "cat";

import "std.zig";

pub fn main(args: [][]u8) error => {
    const exe = args[0];
    var catted_anything = false;
    for (arg in args[1...]) {
        if (arg == "-") {
            catted_anything = true;
            cat_stream(stdin) !! (err) => return err;
        } else if (arg[0] == '-') {
            return usage(exe);
        } else {
            var is: InputStream;
            is.open(arg, OpenReadOnly) !! (err) => {
                stderr.print("Unable to open file: {}", ([]u8])(err));
                return err;
            }
            defer is.close();

            catted_anything = true;
            cat_stream(is) !! (err) => return err;
        }
    }
    if (!catted_anything) {
        cat_stream(stdin) !! (err) => return err;
    }
}

fn usage(exe: []u8) error => {
    stderr.print("Usage: {} [FILE]...\n");
    return error.Invalid;
}

fn cat_stream(is: InputStream) error => {
    var buf: [1024 * 4]u8;

    while (true) {
        const bytes_read = is.read(buf);
        if (bytes_read < 0) {
            stderr.print("Unable to read from stream: {}", ([]u8)(is.err));
            return is.err;
        }

        const bytes_written = stdout.write(buf[0...bytes_read]);
        if (bytes_written < bytes_read) {
            stderr.print("Unable to write to stdout: {}", ([]u8)(stdout.err));
            return stdout.err;
        }
    }
}
