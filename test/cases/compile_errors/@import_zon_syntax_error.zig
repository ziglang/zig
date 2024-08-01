pub fn main() void {
    const f: bool = @import("zon/syntax_error.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/syntax_error.zon
//
// syntax_error.zon:3:13: error: expected ',' after initializer
