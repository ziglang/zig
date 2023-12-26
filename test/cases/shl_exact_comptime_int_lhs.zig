export fn entry() void {
    if (@shlExact(1, 1) != 2) @compileError("should be 2");
}

// compile
// output_mode=Obj
