pub fn main() void {
    const z = true || false;
    _ = z;
}

// error
//
// :2:15: error: expected error set type, found 'bool'
// :2:20: note: '||' merges error sets; 'or' performs boolean OR
