export fn entry() void {
    const x: [*]const bool = true;
    _ = x;
}

// attempted implicit cast from T to [*]const T
//
// tmp.zig:2:30: error: expected type '[*]const bool', found 'bool'
