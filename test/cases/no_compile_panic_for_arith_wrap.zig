pub const panic = @compileError("");

export fn entry() usize {
    var x: usize = 0;
    x +%= 1;
    x -%= 1;
    x *%= 1;
    return x;
}

// compile
// output_mode=Obj
