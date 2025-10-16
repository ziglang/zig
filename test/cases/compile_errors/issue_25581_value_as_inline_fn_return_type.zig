inline fn a() null {
    return null;
}

pub fn main() void {
    _ = a();
}

// error
//
// :1:15: error: expected type 'type', found '@TypeOf(null)'
