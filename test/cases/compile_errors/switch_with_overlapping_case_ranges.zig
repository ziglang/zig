export fn entry() void {
    var q: u8 = 0;
    switch ((&q).*) {
        1...2 => {},
        0...255 => {},
    }
}

// error
//
// :5:10: error: duplicate switch value
// :4:10: note: previous value here
