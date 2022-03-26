export fn entry() usize {
    return @sizeOf(@TypeOf(null));
}

// @sizeOf bad type
//
// tmp.zig:2:20: error: no size available for type '@Type(.Null)'
