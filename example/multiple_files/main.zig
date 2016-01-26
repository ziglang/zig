export executable "test-multiple-files";

import "std.zig";
import "foo.zig";

pub fn main(args: [][]u8) -> %void {
    private_function();
    stdout.printf("OK 2\n");
}

fn private_function() {
    print_text();
}
