export executable "guess_number";

use "std.zig";

// TODO don't duplicate these; implement pub const
const stdout_fileno : isize = 1;
const stderr_fileno : isize = 2;

pub fn main(argc: isize, argv: &&u8, env: &&u8) -> i32 {
    print_str("Welcome to the Guess Number Game in Zig.\n");

    var seed : u32;
    var err : isize;
    // TODO #sizeof(u32) instead of 4
    if ({err = os_get_random_bytes(&seed as &u8, 4); err != 4}) {
        // TODO full error message
        fprint_str(stderr_fileno, "unable to get random bytes");
        return 1;
    }

    print_str("Seed: ");
    print_u64(seed);
    print_str("\n");

    /*
    var rand_state = rand_init(seed);

    const answer = rand_int(&rand_state, 0, 100) + 1;

    while (true) {
        const line = readline("\nGuess a number between 1 and 100: ");

        if (const guess ?= parse_number(line)) {
            if (guess > answer) {
                print_str("Guess lower.\n");
            } else if (guess < answer) {
                print_str("Guess higher.\n");
            } else {
                print_str("You win!\n");
                return 0;
            }
        } else {
            print_str("Invalid number format.\n");
        }
    }
    */

    return 0;
}
