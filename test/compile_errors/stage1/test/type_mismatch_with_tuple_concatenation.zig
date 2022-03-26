export fn entry() void {
    var x = .{};
    x = x ++ .{ 1, 2, 3 };
}

// type mismatch with tuple concatenation
//
// tmp.zig:3:11: error: expected type 'struct:2:14', found 'struct:3:11'
