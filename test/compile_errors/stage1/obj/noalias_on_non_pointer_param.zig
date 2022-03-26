fn f(noalias x: i32) void { _ = x; }
export fn entry() void { f(1234); }

// noalias on non pointer param
//
// tmp.zig:1:6: error: noalias on non-pointer parameter
