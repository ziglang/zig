const Letter = extern union {
    A,
};
export fn entry() void {
    var a = Letter { .A = {} };
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: union field missing type
