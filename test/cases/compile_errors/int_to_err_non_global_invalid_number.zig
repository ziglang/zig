const Set1 = error{
    A,
    B,
};
const Set2 = error{
    A,
    C,
};
comptime {
    var x = @intFromError(Set1.B);
    var y = @errSetCast(Set2, @errorFromInt(x));
    _ = y;
}

// error
// backend=llvm
// target=native
//
// :11:13: error: 'error.B' not a member of error set 'error{C,A}'
