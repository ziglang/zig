const value: u8 = 1;
const ptr = &value;

comptime {
    _ = ptr[0..];
}

comptime {
    _ = ptr[1..2];
}

comptime {
    _ = ptr[0..2];
}

comptime {
    _ = ptr[2..2];
}

export fn entry1() void {
    var start: usize = 0;
    _ = &start;
    _ = ptr[start..2];
}

export fn entry2() void {
    var end: usize = 0;
    _ = &end;
    _ = ptr[0..end];
}

// error
//
// :5:12: error: slice of single-item pointer must have comptime-known bounds [0..0], [0..1], or [1..1]
// :9:13: error: slice of single-item pointer must have comptime-known bounds [0..0], [0..1], or [1..1]
// :9:13: note: expected '0', found '1'
// :13:16: error: slice of single-item pointer must have comptime-known bounds [0..0], [0..1], or [1..1]
// :13:16: note: expected '1', found '2'
// :17:16: error: end index 2 out of bounds for slice of single-item pointer
// :23:13: error: unable to resolve comptime value
// :23:13: note: slice of single-item pointer must have comptime-known bounds [0..0], [0..1], or [1..1]
// :29:16: error: unable to resolve comptime value
// :29:16: note: slice of single-item pointer must have comptime-known bounds [0..0], [0..1], or [1..1]
