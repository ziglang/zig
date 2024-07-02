pub fn main() void {
    const f: i8 = @import("zon/unescaped_newline.zon");
    _ = f;
}

// error
// backend=stage2
// output_mode=Exe
// imports=zon/unescaped_newline.zon
//
// unescaped_newline.zon:1:1: error: expected expression, found 'invalid bytes'
// unescaped_newline.zon:1:3: note: invalid byte: '\n'
