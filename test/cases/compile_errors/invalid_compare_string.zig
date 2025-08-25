comptime {
    const a = "foo";
    if (a != "foo") unreachable;
}
comptime {
    const a = "foo";
    if (a == "foo") {} else unreachable;
}
comptime {
    const a = "foo";
    if (a != ("foo")) {} // intentionally allow
    if (a == ("foo")) {} // intentionally allow
}
comptime {
    const a = "foo";
    switch (a) {
        "foo" => {},
        else => unreachable,
    }
}
comptime {
    const a = "foo";
    switch (a) {
        ("foo") => {}, // intentionally allow
        else => {},
    }
}

// error
// backend=stage2
// target=native
//
// :3:11: error: cannot compare strings with !=
// :7:11: error: cannot compare strings with ==
// :17:9: error: cannot switch on strings
