export fn f() void {
    try something();
}
fn something() anyerror!void { }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: expected type 'void', found 'anyerror'
