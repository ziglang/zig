export fn entry() void {
    var number_or_error: anyerror!i32 = error.SomethingAwful;
    _ = number_or_error == error.SomethingAwful;
}

// comparison with error union and error value
//
// tmp.zig:3:25: error: operator not allowed for type 'anyerror!i32'
