export fn entry() void {
    var a: u32 = 1;
    var ptr: *align(@alignOf(u32)) anyopaque = &a;
    var b: *u32 = @ptrCast(*u32, ptr);
    var ptr2: *anyopaque = &b;
    _ = ptr2;
}

// error
// backend=stage2
// target=native
//
// :5:28: error: expected type '*anyopaque', found '**u32'
// :5:28: note: pointer type child '*u32' cannot cast into pointer type child 'anyopaque'
