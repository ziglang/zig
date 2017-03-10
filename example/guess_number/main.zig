const std = @import("std");
const io = std.io;
const fmt = std.fmt;
const Rand = std.rand.Rand;
const os = std.os;

pub fn main(args: [][]u8) -> %void {
    %%io.stdout.printf("Welcome to the Guess Number Game in Zig.\n");

    var seed_bytes: [@sizeOf(usize)]u8 = undefined;
    %%os.getRandomBytes(seed_bytes[0...]);
    const seed = std.mem.readInt(seed_bytes, usize, true);
    var rand: Rand = undefined;
    rand.init(seed);

    const answer = rand.rangeUnsigned(u8, 0, 100) + 1;

    while (true) {
        %%io.stdout.printf("\nGuess a number between 1 and 100: ");
        var line_buf : [20]u8 = undefined;

        const line_len = io.stdin.read(line_buf[0...]) %% |err| {
            %%io.stdout.printf("Unable to read from stdin: {}\n", @errorName(err));
            return err;
        };

        const guess = fmt.parseUnsigned(u8, line_buf[0...line_len - 1], 10) %% {
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
