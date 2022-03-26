export fn a() usize {
    return @import("../../above.zig").len;
}

// import outside package
//
// :2:20: error: import of file outside package path: '../../above.zig'
