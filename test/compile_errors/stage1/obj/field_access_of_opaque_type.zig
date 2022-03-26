const MyType = opaque {};

export fn entry() bool {
    var x: i32 = 1;
    return bar(@ptrCast(*MyType, &x));
}

fn bar(x: *MyType) bool {
    return x.blah;
}

// field access of opaque type
//
// tmp.zig:9:13: error: no member named 'blah' in opaque type 'MyType'
