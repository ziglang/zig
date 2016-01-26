export executable "hello";

import "std.zig";

pub fn main(args: [][]u8) -> %void {
    %%stdout.printf("Hello, world!\n");
}
