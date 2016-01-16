export executable "hello";

import "std.zig";

pub fn main(argc: isize, argv: &&u8, env: &&u8) i32 => {
    print_str("Hello, world!\n");
    return 0;
}
