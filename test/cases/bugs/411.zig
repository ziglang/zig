fn assert(ok: bool) void {
    if (!ok) unreachable;
}

test "inline while loop" {
    comptime var i = 0;
    var sum: usize = 0;
    while (i < 3) : (i += 1) {
        const T = switch (i) {
            0 => f32,
            1 => i8,
            2 => bool,
            else => unreachable,
        };
        sum += typeNameLength(T);
    }
    assert(sum == 9);
}

fn typeNameLength(comptime T: type) usize {
    return @typeName(T).len;
}

// error
// is_test=1
// backend=llvm
//
// :8:24: error: cannot store to comptime variable in non-inline loop
// :8:5: note: non-inline loop here
