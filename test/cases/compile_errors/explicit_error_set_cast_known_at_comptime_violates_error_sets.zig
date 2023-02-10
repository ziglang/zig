const Set1 = error {A, B};
const Set2 = error {A, C};
comptime {
    var x = Set1.B;
    var y = @errSetCast(Set2, x);
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :5:13: error: 'error.B' not a member of error set 'error{A,C}'
// :2:14: note: error set declared here
