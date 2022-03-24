export fn foo() void {
    const x = switch (bar()) {
        1, 2 => 1,
        3, 4 => 2,
        else => 3,
    };
    _ = x;
}
fn bar() i32 {
    return 2;
}

// non-const switch number literal
//
// tmp.zig:5:17: error: cannot store runtime value in type 'comptime_int'
