export fn entry() void {
    const f: i8 = @import("zon/negative_zero.zon");
    _ = f;
}

// error
// imports=zon/negative_zero.zon
//
// negative_zero.zon:1:2: error: integer literal '-0' is ambiguous
// negative_zero.zon:1:2: note: use '0' for an integer zero
// negative_zero.zon:1:2: note: use '-0.0' for a floating-point signed zero
