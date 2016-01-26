export executable "guess_number";

import "std.zig";
import "rand.zig";

pub fn main(args: [][]u8) -> %void {
    %%stderr.print_str("Welcome to the Guess Number Game in Zig.\n");

    var seed : u32;
    const seed_bytes = (&u8)(&seed)[0...4];
    %%os_get_random_bytes(seed_bytes);

    var rand = rand_new(seed);

    const answer = rand.range_u64(0, 100) + 1;

    while (true) {
        %%stderr.print_str("\nGuess a number between 1 and 100: ");
        var line_buf : [20]u8;

        const line_len = stdin.read(line_buf) %% |err| {
            %%stderr.print_str("Unable to read from stdin.\n");
            return err;
        };

        const guess = parse_u64(line_buf[0...line_len - 1], 10) %% {
            %%stderr.print_str("Invalid number.\n");
            continue;
        };
        if (guess > answer) {
            %%stderr.print_str("Guess lower.\n");
        } else if (guess < answer) {
            %%stderr.print_str("Guess higher.\n");
        } else {
            %%stderr.print_str("You win!\n");
            return;
        }
    }
}
