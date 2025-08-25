export fn entry() void {
    const U = union { A: u32, B: u64 };
    var u = U{ .A = 42 };
    var ok = u == .A;
    _ = &u;
    _ = &ok;
}

// error
// backend=stage2
// target=native
//
// :4:14: error: comparison of union and enum literal is only valid for tagged union types
// :2:15: note: union 'tmp.entry.U' is not a tagged union
