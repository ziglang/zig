const Set1 = error{
    A,
    B,
};
comptime {
    var x: u16 = 3;
    var y = @intToError(x);
    _ = y;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:7:13: error: integer value 3 represents no error
