export fn entry() usize {
    return @sizeOf(@TypeOf(null));
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:20: error: no size available for type '@Type(.Null)'
