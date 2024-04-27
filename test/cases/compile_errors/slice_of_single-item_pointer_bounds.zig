const value: u8 = 1;
const ptr = &value;

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
// :9:16: error: slice end out of bounds: end 2, length 1
// :13:16: error: slice end out of bounds: end 2, length 1
// :17:16: error: slice end out of bounds: end 2, length 1
// :23:13: error: start index of slice of pointer-to-one must be comptime-known
// :29:16: error: end index of slice of pointer-to-one must be comptime-known
