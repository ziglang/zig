export fn entry() void {
    var x: i32 = 1234;
    var p: *i32 = &x;
    const pp: *?*i32 = &p;
    pp.* = null;
    _ = p.*;
}

// error
// backend=stage2
// target=native
//
// :4:24: error: expected type '*?*i32', found '**i32'
// :4:24: note: pointer type child '*i32' cannot cast into pointer type child '?*i32'
// :4:24: note: mutable '*i32' allows illegal null values stored to type '?*i32'
