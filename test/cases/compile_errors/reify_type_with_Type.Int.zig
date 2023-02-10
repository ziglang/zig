const builtin = @import("std").builtin;
export fn entry() void {
    _ = @Type(builtin.Type.Int{
        .signedness = .signed,
        .bits = 8,
    });
}

// error
// backend=stage2
// target=native
//
// :3:31: error: expected type 'builtin.Type', found 'builtin.Type.Int'
// :?:?: note: struct declared here
// :?:?: note: union declared here
