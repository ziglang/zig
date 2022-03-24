const Set1 = error {A, B};
const Set2 = error {A, C};
comptime {
    var x = Set1.B;
    var y = @errSetCast(Set2, x);
    _ = y;
}

// explicit error set cast known at comptime violates error sets
//
// tmp.zig:5:13: error: error.B not a member of error set 'Set2'
