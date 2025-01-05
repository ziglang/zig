export fn entry() void {
    const f: bool = @import("zon/syntax_error.zon");
    _ = f;
}

// error
// imports=zon/syntax_error.zon
//
// syntax_error.zon:3:13: error: expected ',' after initializer
