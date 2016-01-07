export executable "guess_number";

use "std.zig";
use "rand.zig";

// TODO don't duplicate these; implement pub const
const stdout_fileno : isize = 1;
const stderr_fileno : isize = 2;

pub fn main(argc: isize, argv: &&u8, env: &&u8) -> i32 {
    print_str("Welcome to the Guess Number Game in Zig.\n");

    var seed : u32;
    var err : isize;
    if ({err = os_get_random_bytes(&seed as &u8, #sizeof(u32)); err != #sizeof(u32)}) {
        // TODO full error message
        fprint_str(stderr_fileno, "unable to get random bytes\n");
        return 1;
    }

    var rand : Rand;
    rand.init(seed);

    const answer = rand.range_u64(0, 100) + 1;

    print_str("Answer: ");
    print_u64(answer);
    print_str("\n");

    while (true) {
        print_str("\nGuess a number between 1 and 100: ");
        var line_buf : [20]u8;
        const line = readline(line_buf) ?? {
            // TODO full error message
            fprint_str(stderr_fileno, "unable to read input\n");
            return 1;
        };

        if (const guess ?= parse_u64(line)) {
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
}
