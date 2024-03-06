export fn entry() void {
    var q: u8 = 0;
    switch ((&q).*) {
        1...2 => {},
        0...255 => {},
    }
}

// error
// backend=stage2
// target=native
//
// :5:10: error: duplicate switch value
// :4:10: note: previous value here
