fn g() u64 {
    return 0;
}

export fn constEntry() u32 {
    const x: u32 = g();
    return x;
}

export fn varEntry() u32 {
    var x: u32 = g();
    return (&x).*;
}

// error
// backend=stage2
// target=native
//
// :6:21: error: expected type 'u32', found 'u64'
// :6:21: note: unsigned 32-bit int cannot represent all possible unsigned 64-bit values
// :11:19: error: expected type 'u32', found 'u64'
// :11:19: note: unsigned 32-bit int cannot represent all possible unsigned 64-bit values
