export executable "maybe_type";

use "std.zig";

pub fn main(argc: isize, argv: &&u8, env: &&u8) i32 => {
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

    const next_x : ?i32 = null;

    const z = next_x ?? 1234;

    if (z != 1234) {
        print_str("BAD\n");
    }

    const final_x : ?i32 = 13;

    const num = final_x ?? unreachable{};

    if (num != 13) {
        print_str("BAD\n");
    }

    return 0;
}
