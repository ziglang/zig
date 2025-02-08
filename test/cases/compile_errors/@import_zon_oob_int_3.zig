export fn entry() void {
    const f: u64 = @import("zon/int_neg_33.zon");
    _ = f;
}

// error
// imports=zon/int_neg_33.zon
//
// int_neg_33.zon:1:1: error: type 'u64' cannot represent integer value '-33'
// tmp.zig:2:28: note: imported here
