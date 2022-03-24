const u8 = u16;
export fn entry() void {
    const a: u8 = 300;
    _ = a;
}

// declaration with same name as primitive must use special syntax
//
// tmp.zig:1:7: error: name shadows primitive 'u8'
// tmp.zig:1:7: note: consider using @"u8" to disambiguate
