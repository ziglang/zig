const stroo = extern struct {
    moo: ?[*c]u8,
};
export fn testf(fluff: *stroo) void { _ = fluff; }

// error
// backend=stage2
// target=native
//
// :4:8: error: extern structs cannot contain fields of type '?[*c]u8'
// :4:8: note: only pointer like optionals are extern compatible
