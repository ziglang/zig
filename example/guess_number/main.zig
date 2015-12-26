export executable "guess_number";

use "std.zig";

fn main(argc: isize, argv: &&u8, env: &&u8) -> i32 {
    print_str("Welcome to the Guess Number Game in Zig.\n");

    var seed : u32;
    ok_or_panic(os_get_random_bytes(&seed, 4));
    var rand_state = rand_init(seed);

    const answer = rand_int(&rand_state, 0, 100) + 1;

    while true {
        const line = readline("\nGuess a number between 1 and 100: ");

        if const guess ?= parse_number(line) {
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

    return 0;
}
