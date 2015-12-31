export executable "maybe_type";

use "std.zig";

fn main(argc: isize, argv: &&u8, env: &&u8) -> i32 {
    const x : ?bool = true;

    if (const y ?= x) {
        if (y) {
            print_str("x is true\n");
        } else {
            print_str("x is false\n");
        }
    } else {
        print_str("x is none\n");
    }

    return 0;
}
