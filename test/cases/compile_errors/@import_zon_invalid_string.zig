export fn entry() void {
    const f: []const u8 = @import("zon/invalid_string.zon");
    _ = f;
}

// error
// imports=zon/invalid_string.zon
//
// invalid_string.zon:1:5: error: invalid escape character: 'a'
