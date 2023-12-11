pub export fn entry() void {
    var a = false;
    _ = &a;
    const arr1 = .{ 1, 2, 3 };
    loop: inline for (arr1) |val1| {
        _ = val1;
        if (a) {
            const arr = .{ 1, 2, 3 };
            inline for (arr) |val| {
                if (val < 3) continue :loop;
                if (val != 3) unreachable;
            }
        }
    }
}

// error
// backend=stage2
// target=native
//
// :10:30: error: comptime control flow inside runtime block
// :7:13: note: runtime control flow here
