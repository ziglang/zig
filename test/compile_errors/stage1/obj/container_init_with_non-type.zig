const zero: i32 = 0;
const a = zero{1};

export fn entry() usize { return @sizeOf(@TypeOf(a)); }

// container init with non-type
//
// tmp.zig:2:11: error: expected type 'type', found 'i32'
