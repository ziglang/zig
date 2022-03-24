export fn f() void {
    var s: struct {} align(4) = undefined;
    _ = s;
}

// aligned variable of zero-bit type
//
// tmp.zig:2:5: error: variable 's' of zero-bit type 'struct:2:12' has no in-memory representation, it cannot be aligned
