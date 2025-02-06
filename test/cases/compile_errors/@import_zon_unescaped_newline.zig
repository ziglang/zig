export fn entry() void {
    const f: i8 = @import("zon/unescaped_newline.zon");
    _ = f;
}

// error
// imports=zon/unescaped_newline.zon
//
// unescaped_newline.zon:1:1: error: expected expression, found 'invalid token'
