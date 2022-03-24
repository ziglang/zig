const a: *u8 = null;

export fn entry() usize { return @sizeOf(@TypeOf(a)); }

// assign null to non-optional pointer
//
// tmp.zig:1:16: error: expected type '*u8', found '@Type(.Null)'
