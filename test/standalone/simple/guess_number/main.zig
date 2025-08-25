const builtin = @import("builtin");
const std = @import("std");

pub fn main() !void {
    var stdout_writer = std.fs.File.stdout().writerStreaming(&.{});
    const out = &stdout_writer.interface;
    const stdin: std.fs.File = .stdin();

    try out.writeAll("Welcome to the Guess Number Game in Zig.\n");

    const answer = std.crypto.random.intRangeLessThan(u8, 0, 100) + 1;

    while (true) {
        try out.writeAll("\nGuess a number between 1 and 100: ");
        var line_buf: [20]u8 = undefined;
        const amt = try stdin.read(&line_buf);
        if (amt == line_buf.len) {
            try out.writeAll("Input too long.\n");
            continue;
        }
        const line = std.mem.trimEnd(u8, line_buf[0..amt], "\r\n");

        const guess = std.fmt.parseUnsigned(u8, line, 10) catch {
            try out.writeAll("Invalid number.\n");
            continue;
        };
        if (guess > answer) {
            try out.writeAll("Guess lower.\n");
        } else if (guess < answer) {
            try out.writeAll("Guess higher.\n");
        } else {
            try out.writeAll("You win!\n");
            return;
        }
    }
}
