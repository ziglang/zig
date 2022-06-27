comptime {
    const z = error.A > error.B;
    _ = z;
}

// error
// backend=stage2
// target=native
//
// :2:23: error: operator > not allowed for type 'error{A,B}'
