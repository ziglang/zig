comptime {
    var a: bool = undefined;
    _ = &a;
    _ = a and a;
}

// error
//
// :4:9: error: use of undefined value here causes illegal behavior
