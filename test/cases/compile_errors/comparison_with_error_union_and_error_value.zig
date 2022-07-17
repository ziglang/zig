export fn entry() void {
    var number_or_error: anyerror!i32 = error.SomethingAwful;
    _ = number_or_error == error.SomethingAwful;
}

// error
// backend=stage2
// target=native
//
// :3:25: error: operator == not allowed for type 'anyerror!i32'
