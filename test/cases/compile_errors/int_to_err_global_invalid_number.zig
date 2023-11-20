const Set1 = error{
    A,
    B,
};
comptime {
    var x: u16 = 3;
    var y = @errorFromInt(x);
    _ = .{ &x, &y };
}

// error
// backend=stage2
// target=native
//
// :7:27: error: integer value '3' represents no error
