export fn entry() void {
    const f: struct { foo: type } = @import("zon/type_decl.zon");
    _ = f;
}

// error
// imports=zon/type_decl.zon
//
// type_decl.zon:2:12: error: types are not available in ZON
