comptime { var x = doesnt_exist.whatever; _ = x; }

// error
// backend=stage2
// target=native
//
// :1:20: error: use of undeclared identifier 'doesnt_exist'
