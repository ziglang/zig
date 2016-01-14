export executable "test-multiple-files";

use "std.zig";
use "foo.zig";

pub fn main(argc: isize, argv: &&u8, env: &&u8) i32 => {
    private_function();
    print_str("OK 2\n");
    return 0;
}

fn private_function() => {
    print_text();
}
