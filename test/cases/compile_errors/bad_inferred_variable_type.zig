pub fn main() void {
    var x = null;
    _ = &x;
}

// error
// output_mode=Exe
//
// :2:9: error: variable of type '@TypeOf(null)' must be const or comptime
