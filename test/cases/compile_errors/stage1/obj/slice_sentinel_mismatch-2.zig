fn foo() [:0]u8 {
    var x: []u8 = undefined;
    return x;
}
comptime { _ = foo; }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:12: error: expected type '[:0]u8', found '[]u8'
// tmp.zig:3:12: note: destination pointer requires a terminating '0' sentinel
