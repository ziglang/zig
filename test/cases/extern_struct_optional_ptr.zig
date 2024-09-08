export const foo = blk: {
    var ret: extern struct {
        field: ?*u8 = null,
    } = undefined;
    @as(*usize, @ptrCast(&ret)).* = 0;
    break :blk ret;
};

// compile
//
