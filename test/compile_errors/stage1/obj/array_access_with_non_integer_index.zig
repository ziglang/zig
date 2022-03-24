export fn f() void {
    var array = "aoeu";
    var bad = false;
    array[bad] = array[bad];
}
export fn g() void {
    var array = "aoeu";
    var bad = false;
    _ = array[bad];
}

// array access with non integer index
//
// tmp.zig:4:11: error: expected type 'usize', found 'bool'
// tmp.zig:9:15: error: expected type 'usize', found 'bool'
