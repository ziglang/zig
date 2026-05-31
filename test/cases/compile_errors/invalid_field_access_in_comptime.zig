comptime {
    var x = doesnt_exist.whatever;
    _ = x;
}

// error
//
// :2:13: error: use of undeclared identifier 'doesnt_exist'
