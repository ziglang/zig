export fn entry() void {
    {
        const f: i7 = @import("zon/char_32.zon");
        _ = f;
    }
    {
        const f: i6 = @import("zon/char_32.zon");
        _ = f;
    }
}

// error
// imports=zon/char_32.zon
//
// char_32.zon:1:1: error: type 'i6' cannot represent integer value '32'
// tmp.zig:7:31: note: imported here
