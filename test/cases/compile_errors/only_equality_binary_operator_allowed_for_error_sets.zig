comptime {
    const z = error.A > error.B;
    _ = z;
}

// error
//
// :2:23: error: operator > not allowed for type 'error{A,B}'
