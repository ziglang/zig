const x = 0;
const y: ?usize = null;
comptime {
    x += y;
}

// error
//
// :4:10: error: expected type 'comptime_int', found '?usize'
