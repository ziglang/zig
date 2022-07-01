pub fn f() void {
    var bar: bool = true;
    const S = struct {
        fn baz() bool {
            return bar;
        }
    };
    _ = S;
}

// error
//
// :5:20: error: mutable 'bar' not accessible from here
// :2:9: note: declared mutable here
// :3:15: note: crosses namespace boundary here
