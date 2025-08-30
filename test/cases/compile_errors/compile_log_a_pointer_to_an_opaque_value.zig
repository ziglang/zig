export fn entry() void {
    @compileLog(@as(*const anyopaque, @ptrCast(&entry)));
}

// error
//
// :2:5: error: found compile log statement
//
// Compile Log Output:
// @as(*const anyopaque, @as(*const anyopaque, @ptrCast(&tmp.entry)))
