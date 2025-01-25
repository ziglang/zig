export fn entry() i32 {
    if (true || false) {
        return 1234;
    }
    return 5678;
}

// error
//
// :2:9: error: expected error set type, found 'bool'
// :2:14: note: '||' merges error sets; 'or' performs boolean OR
