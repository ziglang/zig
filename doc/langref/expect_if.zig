pub fn a(x: u32) void {
    if (@expect(x == 0, false)) {
        // condition check falls through at code generation
        return;
    } else {
        // condition is branched to at code generation
        return;
    }
}

test "expect" {
    a(10);
}

// test
