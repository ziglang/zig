pub fn main() void {
    maybeErr() catch unreachable;
}

fn maybeErr() !void {
    return;
}

// run
//
