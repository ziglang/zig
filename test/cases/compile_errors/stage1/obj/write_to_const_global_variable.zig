const x : i32 = 99;
fn f() void {
    x = 1;
}
export fn entry() void { f(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:9: error: cannot assign to constant
