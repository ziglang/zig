export fn entry() void {
    _ = if(true) {};
    var good = {};
    _ = if(true) {}
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:20: error: expected ';' after statement
