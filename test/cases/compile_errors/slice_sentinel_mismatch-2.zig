fn foo() [:0]u8 {
    const x: []u8 = undefined;
    return x;
}
comptime {
    _ = &foo;
}

// error
// backend=stage2
// target=native
//
// :3:12: error: expected type '[:0]u8', found '[]u8'
// :3:12: note: destination pointer requires '0' sentinel
// :1:10: note: function return type declared here
