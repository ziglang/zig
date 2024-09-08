export fn test_a() void {
    var x: bool = undefined;
    x = false; // bug only works on var
    const a = while (x) : ({}) {
        if (x) continue;
        break @as(usize, 0);
    } else unreachable;
    _ = a;
}

export fn test_b() void {
    var x: bool = undefined;
    x = false; // bug only works on var
    const a = for (&[1]u8{0}) |_| {
        if (!x) continue;
        break @as(usize, 0);
    } else unreachable;
    _ = a;
}

// compile
//
