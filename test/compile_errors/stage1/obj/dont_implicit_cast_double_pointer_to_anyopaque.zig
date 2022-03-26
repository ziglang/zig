export fn entry() void {
    var a: u32 = 1;
    var ptr: *align(@alignOf(u32)) anyopaque = &a;
    var b: *u32 = @ptrCast(*u32, ptr);
    var ptr2: *anyopaque = &b;
    _ = ptr2;
}

// don't implicit cast double pointer to *anyopaque
//
// tmp.zig:5:29: error: expected type '*anyopaque', found '**u32'
