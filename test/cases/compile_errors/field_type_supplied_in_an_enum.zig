const Letter = enum {
    A: void,
    B,
    C,
};

// error
// backend=stage2
// target=native
//
// :2:8: error: enum fields do not have types
// :1:16: note: consider 'union(enum)' here to make it a tagged union
