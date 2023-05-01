export fn a() void {
    const S = struct { x: i32, y: i32 };
    var s: S = undefined;
    s[0] = 10;
}

// error
// backend=stage2
// target=native
//
// :4:6: error: element access of non-indexable type 'tmp.a.S'
