pub fn a(x: u32) void {
    if (@expect(x == 0, false)) {
        // condition is branched to at runtime
        return;
    } else {
        // condition check falls through
        return;
    }
}

test "expect" {
    a(10);
}

// test
