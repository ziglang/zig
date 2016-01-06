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

    if (accumulator != 15) {
        print_str("BAD\n");
    }

    if (get_array_len(array) != 5) {
        print_str("BAD\n");
    }

    print_str("OK\n");
    return 0;
}

fn get_array_len(a: []u32) -> usize {
    a.len
}
