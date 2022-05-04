const builtin = @import("std").builtin;
var globalTypeInfo : builtin.Type = undefined;
export fn entry() void {
    _ = @Type(globalTypeInfo);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:15: error: unable to evaluate constant expression
