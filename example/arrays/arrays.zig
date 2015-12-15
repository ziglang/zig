export executable "arrays";

use "std.zig";

export fn main(argc: isize, argv: &&u8, env: &&u8) -> i32 {
    let mut array : [i32; 5];

    let mut i : i32 = 0;
loop_start:
    if i == 5 {
        goto loop_end;
    }
    array[i] = i + 1;
    i = array[i];
    goto loop_start;

loop_end:

    i = 0;
    let mut accumulator : i32 = 0;
loop_2_start:
    if i == 5 {
        goto loop_2_end;
    }

    accumulator += array[i];

    i = i + 1;
    goto loop_2_start;
loop_2_end:

    if accumulator == 15 {
        print_str("OK\n" as string);
    }


    return 0;
}
