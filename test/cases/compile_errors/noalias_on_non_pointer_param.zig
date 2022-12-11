fn f(noalias x: i32) void { _ = x; }
export fn entry() void { f(1234); }

// error
// backend=stage2
// target=native
//
// :1:6: error: non-pointer parameter declared noalias
