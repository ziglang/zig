comptime {
    inline for ("foo") |_| {}
}

// error
//
// :2:5: error: redundant inline keyword in comptime scope
