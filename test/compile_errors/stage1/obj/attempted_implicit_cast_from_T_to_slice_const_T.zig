export fn entry() void {
    const x: [*]const bool = true;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:30: error: expected type '[*]const bool', found 'bool'
