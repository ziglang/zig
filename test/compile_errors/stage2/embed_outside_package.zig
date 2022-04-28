export fn a() usize {
    return @embedFile("/root/foo").len;
}

// error
// target=native
//
//:2:23: error: embed of file outside package path: '/root/foo'
