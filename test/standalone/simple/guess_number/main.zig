const builtin = @import("builtin");
const std = @import("std");
const io = std.io;
const fmt = std.fmt;

pub fn main() !void {
    const stdout = io.getStdOut().writer();
    const stdin = io.getStdIn();

    try stdout.print("Welcome to the Guess Number Game in Zig.\n", .{});

    const answer = std.crypto.random.intRangeLessThan(u8, 0, 100) + 1;

    while (true) {
        try stdout.print("\nGuess a number between 1 and 100: ", .{});
        var line_buf: [20]u8 = undefined;

        const amt = try stdin.read(&line_buf);
        if (amt == line_buf.len) {
            try stdout.print("Input too long.\n", .{});
            continue;
        }
        const line = std.mem.trimRight(u8, line_buf[0..amt], "\r\n");

        const guess = fmt.parseUnsigned(u8, line, 10) catch {
            try stdout.print("Invalid number.\n", .{});
            continue;
        };
        if (guess > answer) {
            try stdout.print("Guess lower.\n", .{});
        } else if (guess < answer) {
            try stdout.print("Guess higher.\n", .{});
        } else {
            try stdout.print("You win!\n", .{});
            return;
        }
    }
}
