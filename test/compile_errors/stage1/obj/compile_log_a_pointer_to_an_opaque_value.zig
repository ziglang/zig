export fn entry() void {
    @compileLog(@ptrCast(*const anyopaque, &entry));
}

// compile log a pointer to an opaque value
//
// tmp.zig:2:5: error: found compile log statement
