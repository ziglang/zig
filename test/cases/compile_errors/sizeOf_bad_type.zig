export fn entry() usize {
    return @sizeOf(@TypeOf(null));
}

// error
//
// :2:20: error: no size available for type '@TypeOf(null)'
