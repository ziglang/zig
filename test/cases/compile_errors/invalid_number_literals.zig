comptime {
    _ = 0e.0;
}
comptime {
    _ = 0E.0;
}
comptime {
    _ = 12e.0;
}
comptime {
    _ = 12E.0;
}
comptime {
    _ = 0xp0;
}
comptime {
    _ = 0xP0;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: unexpected period after exponent
// :5:11: error: unexpected period after exponent
// :8:12: error: unexpected period after exponent
// :11:12: error: unexpected period after exponent
// :14:9: error: expected a digit after base prefix
// :17:9: error: expected a digit after base prefix
