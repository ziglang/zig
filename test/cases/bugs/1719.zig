fn C1(x: i32, y: i32) [1]u8 {
    _ = x;
    _ = y;
    return [_]u8{1};
}
fn C2(x: i32, y: i32) [2]u8 {
    return C1(x, y) ++ C1(x + 1, y);
}

test {
    const pixels = comptime (C2(0, 0));
    _ = pixels;
}

// run
// is_test=1
// backend=stage2
