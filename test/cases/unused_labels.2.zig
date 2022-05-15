comptime {
    foo: for ("foo") |_| {}
}

// error
//
// :2:5: error: unused for loop label
