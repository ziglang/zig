comptime {
    var a = "foo";
    if (a == "foo") unreachable;
}
comptime {
    var a = "foo";
    if (a == ("foo")) unreachable; // intentionally allow
}
comptime {
    var a = "foo";
    switch (a) {
        "foo" => unreachable,
        else => {},
    }
}
comptime {
    var a = "foo";
    switch (a) {
        ("foo") => unreachable, // intentionally allow
        else => {},
    }
}

// error
// backend=stage2
// target=native
//
// :3:11: error: cannot compare strings with ==
// :12:9: error: cannot switch on strings
