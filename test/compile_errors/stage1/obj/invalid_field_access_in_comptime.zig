comptime { var x = doesnt_exist.whatever; _ = x; }

// invalid field access in comptime
//
// tmp.zig:1:20: error: use of undeclared identifier 'doesnt_exist'
