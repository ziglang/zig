const std = @import("std");
const expectEqual = std.testing.expectEqual;

const Instruction = enum {
    add,
    mul,
    end,
};

fn evaluate(initial_stack: []const i32, code: []const Instruction) !i32 {
    var stack = try std.BoundedArray(i32, 8).fromSlice(initial_stack);
    var ip: usize = 0;

    return vm: switch (code[ip]) {
        // Because all code after `continue` is unreachable, this branch does
        // not provide a result.
        .add => {
            try stack.append(stack.pop().? + stack.pop().?);

            ip += 1;
            continue :vm code[ip];
        },
        .mul => {
            try stack.append(stack.pop().? * stack.pop().?);

            ip += 1;
            continue :vm code[ip];
        },
        .end => stack.pop().?,
    };
}

test "evaluate" {
    const result = try evaluate(&.{ 7, 2, -3 }, &.{ .mul, .add, .end });
    try expectEqual(1, result);
}

// test
