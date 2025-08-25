fn foo(s: []u8) void {
    _ = s;
}

test "string literal to mutable slice" {
    foo("hello");
}

// test_error=expected type '[]u8', found '*const [5:0]u8'
