const stroo = extern struct {
    moo: ?[*c]u8,
};
export fn testf(fluff: *stroo) void { _ = fluff; }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: extern structs cannot contain fields of type '?[*c]u8'
