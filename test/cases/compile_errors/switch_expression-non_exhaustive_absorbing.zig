const E = enum(u8) {
    a,
    b,
    _,
};
const U = union(E) {
    a: i32,
    b: u32,
};
pub export fn entry1() void {
    const e: E = .b;
    switch (e) { // error: switch not handling the tag `b`
        .a, _ => {},
    }
}
pub export fn entry2() void {
    const u = U{ .a = 2 };
    switch (u) { // error: `_` prong not allowed when switching on tagged union
        .a => {},
        .b, _ => {},
    }
}

// error
//
// :12:5: error: switch must handle all possibilities
// :3:5: note: unhandled enumeration value: 'b'
// :1:11: note: enum 'tmp.E' declared here
// :18:5: error: '_' prong only allowed when switching on non-exhaustive enums
// :20:13: note: '_' prong here
// :18:5: note: consider using 'else'
