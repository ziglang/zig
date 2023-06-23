pub fn testTrickyDefer() !void {
    defer canFail() catch {};

    defer try canFail();

    const a = maybeInt() orelse return;
}

fn canFail() anyerror!void {}

pub fn maybeInt() ?i32 {
    return 0;
}

export fn entry() usize {
    return @sizeOf(@TypeOf(testTrickyDefer));
}

// error
// backend=stage2
// target=native
//
// :4:11: error: 'try' not allowed inside defer expression
// :4:5: note: defer expression here
