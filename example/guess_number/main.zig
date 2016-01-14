export executable "guess_number";

use "std.zig";
use "rand.zig";

pub fn main(argc: isize, argv: &&u8, env: &&u8) i32 => {
    print_str("Welcome to the Guess Number Game in Zig.\n");

    var seed : u32;
    const err = os_get_random_bytes((&u8)(&seed), @sizeof(u32));
    if (err != @sizeof(u32)) {
        // TODO full error message
        fprint_str(stderr_fileno, "unable to get random bytes\n");
        return 1;
    }

    var rand : Rand;
    rand.init(seed);

    const answer = rand.range_u64(0, 100) + 1;

    while (true) {
        print_str("\nGuess a number between 1 and 100: ");
        var line_buf : [20]u8;
        var line_len : usize;
        // TODO fix this awkward error handling
        if (readline(line_buf, &line_len) || line_len == line_buf.len) {
            // TODO full error message
            fprint_str(stderr_fileno, "unable to read input\n");
            return 1;
        }

        var guess : u64;
        if (parse_u64(line_buf[0...line_len - 1], 10, &guess)) {
            print_str("Invalid number format.\n");
        } else if (guess > answer) {
            print_str("Guess lower.\n");
        } else if (guess < answer) {
            print_str("Guess higher.\n");
        } else {
            print_str("You win!\n");
            return 0;
        }
    }
}
