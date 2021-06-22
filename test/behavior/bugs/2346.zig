test "fixed" {
    const a: *void = undefined;
    const b: *[1]void = a;
    _ = b;
    const c: *[0]u8 = undefined;
    const d: []u8 = c;
    _ = d;
}
