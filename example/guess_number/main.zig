const builtin = @import("builtin");
const std = @import("std");
const io = std.io;
const fmt = std.fmt;
const os = std.os;

pub fn main() !void {
    var stdout_file = try io.getStdOut();
    var stdout_file_stream = io.FileOutStream.init(&stdout_file);
    const stdout = &stdout_file_stream.stream;

    try stdout.print("Welcome to the Guess Number Game in Zig.\n");

    var seed_bytes: [@sizeOf(u64)]u8 = undefined;
    os.getRandomBytes(seed_bytes[0..]) catch |err| {
        std.debug.warn("unable to seed random number generator: {}", err);
        return err;
    };
    const seed = std.mem.readInt(seed_bytes, u64, builtin.Endian.Big);
    var prng = std.rand.DefaultPrng.init(seed);

    const answer = prng.random.range(u8, 0, 100) + 1;

    while (true) {
        try stdout.print("\nGuess a number between 1 and 100: ");
        var line_buf: [20]u8 = undefined;

        const line_len = io.readLine(line_buf[0..]) catch |err| switch (err) {
            error.InputTooLong => {
                try stdout.print("Input too long.\n");
                continue;
            },
            error.EndOfFile, error.StdInUnavailable => return err,
        };

        const guess = fmt.parseUnsigned(u8, line_buf[0..line_len], 10) catch {
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
