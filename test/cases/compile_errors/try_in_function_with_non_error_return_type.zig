export fn f() void {
    try something();
}
fn something() anyerror!void {}

// error
// backend=stage2
// target=native
//
// :2:5: error: expected type 'void', found 'anyerror'
// :1:15: note: function cannot return an error
