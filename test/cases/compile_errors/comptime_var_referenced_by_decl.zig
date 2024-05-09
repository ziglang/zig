export const a: *u32 = a: {
    var x: u32 = 123;
    break :a &x;
};

export const b: [1]*u32 = b: {
    var x: u32 = 123;
    break :b .{&x};
};

export const c: *[1]u32 = c: {
    var x: u32 = 123;
    break :c (&x)[0..1];
};

export const d: *anyopaque = d: {
    var x: u32 = 123;
    break :d &x;
};

const S = extern struct { ptr: *u32 };
export const e: S = e: {
    var x: u32 = 123;
    break :e .{ .ptr = &x };
};

// The pointer constness shouldn't matter - *any* reference to a comptime var is illegal in a global's value.
export const f: *const u32 = f: {
    var x: u32 = 123;
    break :f &x;
};

// The pointer itself doesn't refer to a comptime var, but from it you can derive a pointer which does.
export const g: *const *const u32 = g: {
    const valid: u32 = 123;
    var invalid: u32 = 123;
    const aggregate: [2]*const u32 = .{ &valid, &invalid };
    break :g &aggregate[0];
};

// error
//
// :1:27: error: global variable contains reference to comptime var
// :6:30: error: global variable contains reference to comptime var
// :11:30: error: global variable contains reference to comptime var
// :16:33: error: global variable contains reference to comptime var
// :22:24: error: global variable contains reference to comptime var
// :28:33: error: global variable contains reference to comptime var
// :34:40: error: global variable contains reference to comptime var
