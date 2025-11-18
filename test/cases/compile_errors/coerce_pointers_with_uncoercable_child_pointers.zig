export fn entry1() void {
    const p: **u32 = undefined;
    const q: **i32 = p;
    _ = q;
}

export fn entry2() void {
    const p: [*]*u32 = undefined;
    const q: [*]*i32 = p;
    _ = q;
}

export fn entry3() void {
    const p: []*u32 = undefined;
    const q: []*i32 = p;
    _ = q;
}

export fn entry4() void {
    const p: [*c]*u32 = undefined;
    const q: [*c]*i32 = p;
    _ = q;
}

export fn entry5() void {
    const p: **[1:42]u8 = undefined;
    const q: **[1]u8 = p;
    _ = q;
}

// error
//
// :3:22: error: expected type '**i32', found '**u32'
// :3:22: note: pointer type child '*u32' cannot cast into pointer type child '*i32'
// :3:22: note: pointer type child 'u32' cannot cast into pointer type child 'i32'
// :3:22: note: signed 32-bit int cannot represent all possible unsigned 32-bit values
// :9:24: error: expected type '[*]*i32', found '[*]*u32'
// :9:24: note: pointer type child '*u32' cannot cast into pointer type child '*i32'
// :9:24: note: pointer type child 'u32' cannot cast into pointer type child 'i32'
// :9:24: note: signed 32-bit int cannot represent all possible unsigned 32-bit values
// :15:23: error: expected type '[]*i32', found '[]*u32'
// :15:23: note: pointer type child '*u32' cannot cast into pointer type child '*i32'
// :15:23: note: pointer type child 'u32' cannot cast into pointer type child 'i32'
// :15:23: note: signed 32-bit int cannot represent all possible unsigned 32-bit values
// :21:25: error: expected type '[*c]*i32', found '[*c]*u32'
// :21:25: note: pointer type child '*u32' cannot cast into pointer type child '*i32'
// :21:25: note: pointer type child 'u32' cannot cast into pointer type child 'i32'
// :21:25: note: signed 32-bit int cannot represent all possible unsigned 32-bit values
// :27:24: error: expected type '**[1]u8', found '**[1:42]u8'
// :27:24: note: pointer type child '*[1:42]u8' cannot cast into pointer type child '*[1]u8'
// :27:24: note: pointer type child '[1:42]u8' cannot cast into pointer type child '[1]u8'
// :27:24: note: source array cannot be guaranteed to maintain '42' sentinel
