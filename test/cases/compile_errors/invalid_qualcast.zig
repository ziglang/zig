pub export fn entry() void {
    var a: [*:0]const volatile u16 = undefined;
    _ = @qualCast([*]u16, a);
}

// error
// backend=stage2
// target=native
//
// :3:9: error: '@qualCast' can only modify 'const' and 'volatile' qualifiers
// :3:9: note: expected type '[*]const volatile u16'
// :3:9: note: got type '[*:0]const volatile u16'
