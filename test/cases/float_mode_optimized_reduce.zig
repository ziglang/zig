pub fn main() void {
    var a: @Vector(2, f32) = @splat(5.0);
    _ = &a;

    @setFloatMode(.optimized);
    var b = @reduce(.Add, a);
    _ = &b;
}

// run
// backend=llvm
//
