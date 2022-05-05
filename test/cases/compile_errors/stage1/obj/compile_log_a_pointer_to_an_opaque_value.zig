export fn entry() void {
    @compileLog(@ptrCast(*const anyopaque, &entry));
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: found compile log statement
