export fn entry() void {
    const x: [*]const bool = true;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:30: error: expected type '[*]const bool', found 'bool'
