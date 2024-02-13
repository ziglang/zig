pub export fn entry1() void {
    var x: anyerror!usize = 5;
    if (x) {
        // foo
    } else |_| {
        // bar
    }
    _ = &x;
}
pub export fn entry2() void {
    var x: anyerror!usize = 5;
    while (x) {
        // foo
    } else |_| {
        // bar
    }
    _ = &x;
}

// error
// backend=stage2
// target=native
//
// :3:5: error: error union payload is ignored
// :3:5: note: payload value can be explicitly ignored with '|_|'
// :12:5: error: error union payload is ignored
// :12:5: note: payload value can be explicitly ignored with '|_|'
