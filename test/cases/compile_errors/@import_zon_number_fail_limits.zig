export fn entry() void {
    const f: i66 = @import("zon/large_number.zon");
    _ = f;
}

// error
// imports=zon/large_number.zon
//
// large_number.zon:1:1: error: type 'i66' cannot represent integer value '36893488147419103232'
// tmp.zig:2:28: note: imported here
