comptime { var x = doesnt_exist.whatever; _ = x; }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:20: error: use of undeclared identifier 'doesnt_exist'
