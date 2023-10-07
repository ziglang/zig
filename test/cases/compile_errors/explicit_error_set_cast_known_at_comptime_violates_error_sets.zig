const Set1 = error{ A, B };
const Set2 = error{ A, C };
comptime {
    var x = Set1.B;
    var y: Set2 = @errorCast(x);
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :5:19: error: 'error.B' not a member of error set 'error{C,A}'
