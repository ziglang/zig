const x : i32 = 99;
fn f() void {
    x = 1;
}
export fn entry() void { f(); }

// write to const global variable
//
// tmp.zig:3:9: error: cannot assign to constant
