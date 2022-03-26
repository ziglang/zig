export fn f() void {
    try something();
}
fn something() anyerror!void { }

// try in function with non error return type
//
// tmp.zig:2:5: error: expected type 'void', found 'anyerror'
