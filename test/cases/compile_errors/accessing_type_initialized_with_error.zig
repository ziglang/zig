const Error: type = error.E;
pub fn main() void {
    const y = Error;
    _ = y;
}

// error
//
// 1:21: error: expected type 'type', found 'error{E}'
