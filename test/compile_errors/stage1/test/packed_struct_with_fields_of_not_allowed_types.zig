const A = packed struct {
    x: anyerror,
};
const B = packed struct {
    x: [2]u24,
};
const C = packed struct {
    x: [1]anyerror,
};
const D = packed struct {
    x: [1]S,
};
const E = packed struct {
    x: [1]U,
};
const F = packed struct {
    x: ?anyerror,
};
const G = packed struct {
    x: Enum,
};
export fn entry1() void {
    var a: A = undefined;
    _ = a;
}
export fn entry2() void {
    var b: B = undefined;
    _ = b;
}
export fn entry3() void {
    var r: C = undefined;
    _ = r;
}
export fn entry4() void {
    var d: D = undefined;
    _ = d;
}
export fn entry5() void {
    var e: E = undefined;
    _ = e;
}
export fn entry6() void {
    var f: F = undefined;
    _ = f;
}
export fn entry7() void {
    var g: G = undefined;
    _ = g;
}
const S = struct {
    x: i32,
};
const U = struct {
    A: i32,
    B: u32,
};
const Enum = enum {
    A,
    B,
};

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:2:5: error: type 'anyerror' not allowed in packed struct; no guaranteed in-memory representation
// tmp.zig:5:5: error: array of 'u24' not allowed in packed struct due to padding bits (must be padded from 48 to 64 bits)
// tmp.zig:8:5: error: type 'anyerror' not allowed in packed struct; no guaranteed in-memory representation
// tmp.zig:11:5: error: non-packed, non-extern struct 'S' not allowed in packed struct; no guaranteed in-memory representation
// tmp.zig:14:5: error: non-packed, non-extern struct 'U' not allowed in packed struct; no guaranteed in-memory representation
// tmp.zig:17:5: error: type '?anyerror' not allowed in packed struct; no guaranteed in-memory representation
// tmp.zig:20:5: error: type 'Enum' not allowed in packed struct; no guaranteed in-memory representation
// tmp.zig:57:14: note: enum declaration does not specify an integer tag type
