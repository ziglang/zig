pub fn main() void {
    maybeErr() catch return;
    unreachable;
}

fn maybeErr() !void {
    return error.NoWay;
}

// run
//
