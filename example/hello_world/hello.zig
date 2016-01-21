export executable "hello";

import "std.zig";

pub fn main(args: [][]u8) i32 => {
    //stderr.print_str("Hello, world!\n");
    print_str("Hello, world!\n");
    return 0;
}
