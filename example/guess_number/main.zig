const std = @import("std");
const io = std.io;
const Rand = std.Rand;
const os = std.os;

pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("Welcome to the Guess Number Game in Zig.\n");

    var seed : u32 = undefined;
    const seed_bytes = (&u8)(&seed)[0...4];
    %%os.get_random_bytes(seed_bytes);

    var rand = Rand.init(seed);

    const answer = rand.range_u64(0, 100) + 1;

    while (true) {
        %%io.stdout.printf("\nGuess a number between 1 and 100: ");
        var line_buf : [20]u8 = undefined;

        const line_len = io.stdin.read(line_buf) %% |err| {
            %%io.stdout.printf("Unable to read from stdin.\n");
            return err;
        };

        const guess = io.parse_unsigned(u8, line_buf[0...line_len - 1], 10) %% {
            %%io.stdout.printf("Invalid number.\n");
            continue;
        };
        if (guess > answer) {
            %%io.stdout.printf("Guess lower.\n");
        } else if (guess < answer) {
            %%io.stdout.printf("Guess higher.\n");
        } else {
            %%io.stdout.printf("You win!\n");
            return;
        }
    }
}
