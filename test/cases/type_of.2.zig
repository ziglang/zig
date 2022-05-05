pub fn main() void {
    _ = @TypeOf(true, 1);
}

// error
//
// :2:9: error: incompatible types: 'bool' and 'comptime_int'
// :2:17: note: type 'bool' here
// :2:23: note: type 'comptime_int' here
