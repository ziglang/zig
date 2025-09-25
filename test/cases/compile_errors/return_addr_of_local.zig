export fn b() void {
    var x: i32 = 1234;
    return &x;
}

// error
//
// :3:13: error: returning address of expired local variable 'x'
// :2:9: note: declared runtime-known here
