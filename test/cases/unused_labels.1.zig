comptime {
    foo: while (true) {}
}

// error
//
// :2:5: error: unused while loop label
