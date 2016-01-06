export executable "arrays";

use "std.zig";

pub fn main(argc: isize, argv: &&u8, env: &&u8) -> i32 {
    var array : [5]u32;

    var i : u32 = 0;
    while (i < 5) {
        array[i] = i + 1;
        i = array[i];
    }

    i = 0;
    var accumulator : u32 = 0;
    while (i < 5) {
        accumulator += array[i];

        i += 1;
    }

    if (accumulator == 15) {
        print_str("OK\n");
    }

    return 0;
}
