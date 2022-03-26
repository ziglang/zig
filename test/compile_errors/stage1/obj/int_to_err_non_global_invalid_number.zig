const Set1 = error{
    A,
    B,
};
const Set2 = error{
    A,
    C,
};
comptime {
    var x = @errorToInt(Set1.B);
    var y = @errSetCast(Set2, @intToError(x));
    _ = y;
}

// int to err non global invalid number
//
// tmp.zig:11:13: error: error.B not a member of error set 'Set2'
