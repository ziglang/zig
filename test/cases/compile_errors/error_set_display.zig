const Set0 = error{ A, B, C, D, E, F };
const Set1 = error{ F, E, D, C, A };
comptime {
    const x = Set0.B;
    const y: Set1 = @errorCast(x);
    _ = y;
}

// error
//
// :5:21: error: 'error.B' not a member of error set 'error{A,C,D,E,F}'
