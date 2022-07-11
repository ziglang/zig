const E = enum { one, two };
comptime {
    @export(E, .{ .name = "E" });
}
const e: E = .two;
comptime {
    @export(e, .{ .name = "e" });
}

// error
// backend=stage2
// target=native
//
// :3:5: error: unable to export type 'type'
// :7:5: error: unable to export type 'tmp.E'
// :7:5: note: enum tag type 'u1' is not extern compatible
// :7:5: note: only integers with power of two bits are extern compatible
// :1:11: note: enum declared here
