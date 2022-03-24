const builtin = @import("std").builtin;
var globalTypeInfo : builtin.Type = undefined;
export fn entry() void {
    _ = @Type(globalTypeInfo);
}

// @Type with non-constant expression
//
// tmp.zig:4:15: error: unable to evaluate constant expression
