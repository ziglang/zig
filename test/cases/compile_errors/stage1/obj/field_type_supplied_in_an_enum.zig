const Letter = enum {
    A: void,
    B,
    C,
};

// error
// backend=stage1
// target=native
//
// tmp.zig:2:8: error: enum fields do not have types
// tmp.zig:1:16: note: consider 'union(enum)' here to make it a tagged union
