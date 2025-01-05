export fn entry() void {
    {
        const f: i7 = @import("zon/int_neg_33.zon");
        _ = f;
    }
    {
        const f: i6 = @import("zon/int_neg_33.zon");
        _ = f;
    }
}

// error
// imports=zon/int_neg_33.zon
//
// int_neg_33.zon:1:1: error: type 'i6' cannot represent integer value '-33'
// tmp.zig:7:31: note: imported here
