export executable "test-multiple-files";

import "std.zig";
import "foo.zig";

pub fn main(args: [][]u8) i32 => {
    private_function();
    stdout.printf("OK 2\n");
    return 0;
}

fn private_function() => {
    print_text();
}
