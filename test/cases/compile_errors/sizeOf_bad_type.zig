export fn entry() usize {
    return @sizeOf(@TypeOf(null));
}

// error
// backend=stage2
// target=native
//
// :2:20: error: no size available for type '@TypeOf(null)'
