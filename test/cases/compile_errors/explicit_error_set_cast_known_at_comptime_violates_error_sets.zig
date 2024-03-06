const Set1 = error{ A, B };
const Set2 = error{ A, C };
comptime {
    const x = Set1.B;
    const y: Set2 = @errorCast(x);
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :5:21: error: 'error.B' not a member of error set 'error{C,A}'
