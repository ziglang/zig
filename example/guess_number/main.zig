const builtin = @import("builtin");
const std = @import("std");
const io = std.io;
const fmt = std.fmt;
const Rand = std.rand.Rand;
const os = std.os;

pub fn main() !void {
    var stdout_file = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout_file);
    const stdout = &stdout_file_stream.stream;

    var stdin_file = try io.getStdIn();

    try stdout.print("Welcome to the Guess Number Game in Zig.\n");

    var seed_bytes: [@sizeOf(usize)]u8 = undefined;
    os.getRandomBytes(seed_bytes[0..]) catch |err| {
        std.debug.warn("unable to seed random number generator: {}", err);
        return err;
    };
    const seed = std.mem.readInt(seed_bytes, usize, builtin.Endian.Big);
    var rand = Rand.init(seed);

    const answer = rand.range(u8, 0, 100) + 1;

    while (true) {
        try stdout.print("\nGuess a number between 1 and 100: ");
        var line_buf : [20]u8 = undefined;

        const line_len = stdin_file.read(line_buf[0..]) catch |err| {
            try stdout.print("Unable to read from stdin: {}\n", @errorName(err));
            return err;
        };

        const guess = fmt.parseUnsigned(u8, line_buf[0..line_len - 1], 10) catch {
            try stdout.print("Invalid number.\n");
            continue;
        };
        if (guess > answer) {
            try stdout.print("Guess lower.\n");
        } else if (guess < answer) {
            try stdout.print("Guess higher.\n");
        } else {
            try stdout.print("You win!\n");
            return;
        }
    }
}
