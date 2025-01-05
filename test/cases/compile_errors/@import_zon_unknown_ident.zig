export fn entry() void {
    const f: struct { value: bool } = @import("zon/unknown_ident.zon");
    _ = f;
}

// error
// imports=zon/unknown_ident.zon
//
// unknown_ident.zon:2:14: error: invalid expression
// unknown_ident.zon:2:14: note: ZON allows identifiers 'true', 'false', 'null', 'inf', and 'nan'
// unknown_ident.zon:2:14: note: precede identifier with '.' for an enum literal
