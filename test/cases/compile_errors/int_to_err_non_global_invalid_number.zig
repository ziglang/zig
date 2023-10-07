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
    var y: Set2 = @errorCast(@errorFromInt(x));
    _ = y;
}

// error
// backend=llvm
// target=native
//
// :11:19: error: 'error.B' not a member of error set 'error{C,A}'
