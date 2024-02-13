pub export fn entry1() void {
    const U = union(enum) {
        a: u32,
        b: noreturn,
        fn foo(_: @This()) void {}
        fn bar() noreturn {
            unreachable;
        }
    };

    var a = U{ .b = undefined };
    _ = &a;
}
pub export fn entry2() void {
    const U = union(enum) {
        a: noreturn,
    };
    var u: U = undefined;
    u = .a;
}
pub export fn entry3() void {
    const U = union(enum) {
        a: noreturn,
        b: void,
    };
    var e = @typeInfo(U).Union.tag_type.?.a;
    var u: U = undefined;
    u = (&e).*;
}

// error
// backend=stage2
// target=native
//
// :11:14: error: cannot initialize 'noreturn' field of union
// :4:9: note: field 'b' declared here
// :2:15: note: union declared here
// :19:10: error: cannot initialize 'noreturn' field of union
// :16:9: note: field 'a' declared here
// :15:15: note: union declared here
// :28:13: error: runtime coercion from enum '@typeInfo(tmp.entry3.U).Union.tag_type.?' to union 'tmp.entry3.U' which has a 'noreturn' field
// :23:9: note: 'noreturn' field here
// :22:15: note: union declared here
