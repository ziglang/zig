const std = @import("std");
const expectEqual = std.testing.expectEqual;

const Instruction = enum {
    mul,
    add,
    end,
};

test "switch dispatch loop" {
    var stack = std.ArrayList(i32).init(std.testing.allocator);
    defer stack.deinit();

    try stack.append(5);
    try stack.append(1);
    try stack.append(-1);

    const instructions: []const Instruction = &.{
        .mul, .add, .end,
    };

    var ip: usize = 0;

    const result = vm: switch (instructions[ip]) {
        .add => {
            const l = stack.pop();
            const r = stack.pop();

            try stack.append(l + r);

            ip += 1;
            continue :vm instructions[ip];
        },
        .mul => {
            const l = stack.pop();
            const r = stack.pop();

            try stack.append(l * r);

            ip += 1;
            continue :vm instructions[ip];
        },
        .end => stack.pop(),
    };

    try expectEqual(4, result);
}

// test

