export fn entry() void {
    var x = .{};
    x = x ++ .{ 1, 2, 3 };
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:3:11: error: expected type 'struct:2:14', found 'struct:3:11'
