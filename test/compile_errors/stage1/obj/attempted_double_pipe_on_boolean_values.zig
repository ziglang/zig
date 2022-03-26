export fn entry(a: bool, b: bool) i32 {
    if (a || b) {
        return 1234;
    }
    return 5678;
}

// attempted `||` on boolean values
//
// tmp.zig:2:9: error: expected error set type, found 'bool'
// tmp.zig:2:11: note: `||` merges error sets; `or` performs boolean OR
