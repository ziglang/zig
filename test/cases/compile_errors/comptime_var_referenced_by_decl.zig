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

// Mutable globals should have the same restrictions as const globals.
export var h: *[1]u32 = h: {
    var x: [1]u32 = .{123};
    break :h &x;
};

// error
//
// :1:27: error: global variable contains reference to comptime var
// :2:5: note: 'a' points to comptime var declared here
// :6:30: error: global variable contains reference to comptime var
// :7:5: note: 'b[0]' points to comptime var declared here
// :11:30: error: global variable contains reference to comptime var
// :12:5: note: 'c' points to comptime var declared here
// :16:33: error: global variable contains reference to comptime var
// :17:5: note: 'd' points to comptime var declared here
// :22:24: error: global variable contains reference to comptime var
// :23:5: note: 'e.ptr' points to comptime var declared here
// :28:33: error: global variable contains reference to comptime var
// :29:5: note: 'f' points to comptime var declared here
// :34:40: error: global variable contains reference to comptime var
// :34:40: note: 'g' points to 'v0[0]', where
// :36:5: note: 'v0[1]' points to comptime var declared here
// :42:28: error: global variable contains reference to comptime var
// :43:5: note: 'h' points to comptime var declared here
