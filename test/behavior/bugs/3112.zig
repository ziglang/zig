const std = @import("std");
const expect = std.testing.expect;

const State = struct {
    const Self = @This();
    enter: fn (previous: ?Self) void,
};

fn prev(p: ?State) void {
    expect(p == null);
}

test "zig test crash" {
    var global: State = undefined;
    global.enter = prev;
    global.enter(null);
}
