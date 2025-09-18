export fn entry(x: i32) usize {
    return @intFromPtr(x);
}

// error
//
// :2:24: error: expected pointer, found 'i32'
