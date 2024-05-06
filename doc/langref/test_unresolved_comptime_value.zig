fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
test "try to pass a runtime type" {
    foo(false);
}
fn foo(condition: bool) void {
    const result = max(
        if (condition) f32 else u64,
        1234,
        5678);
    _ = result;
}

// test_error=unable to resolve comptime value
