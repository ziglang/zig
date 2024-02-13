const E = enum(u8) {
    a,
    b,
    _,
};
const U = union(E) {
    a,
    b,
};
export fn foo() void {
    var e: E = @enumFromInt(15);
    var u: U = e;
    _ = .{ &e, &u };
}
export fn bar() void {
    const e: E = @enumFromInt(15);
    var u: U = e;
    _ = &u;
}

// error
// backend=stage2
// target=native
//
// :12:16: error: runtime coercion to union 'tmp.U' from non-exhaustive enum
// :1:11: note: enum declared here
// :17:16: error: union 'tmp.U' has no tag with value '@enumFromInt(15)'
// :6:11: note: union declared here
