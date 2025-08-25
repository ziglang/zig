const U = union {
    comptime a: u32 = 1,
};
const E = enum {
    comptime a = 1,
};
const P = packed struct {
    comptime a: u32 = 1,
};
const X = extern struct {
    comptime a: u32 = 1,
};

// error
// backend=stage2
// target=native
//
// :2:5: error: union fields cannot be marked comptime
// :5:5: error: enum fields cannot be marked comptime
// :8:5: error: packed struct fields cannot be marked comptime
// :11:5: error: extern struct fields cannot be marked comptime
