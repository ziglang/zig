const E = enum { one, two };
comptime {
    @export(&E, .{ .name = "E" });
}
const e: E = .two;
comptime {
    @export(&e, .{ .name = "e" });
}

// error
// backend=stage2
// target=native
//
// :3:5: error: unable to export type 'type'
// :7:5: error: unable to export type 'tmp.E'
// :7:5: note: enum tag type 'u1' is not extern compatible
// :7:5: note: only integers with 0, 8, 16, 32, 64 and 128 bits are extern compatible
// :1:11: note: enum declared here
