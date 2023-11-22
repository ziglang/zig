pub fn f() void {
    var bar: bool = true;
    _ = &bar;
    const S = struct {
        fn baz() bool {
            return bar;
        }
    };
    _ = S;
}

// error
//
// :6:20: error: mutable 'bar' not accessible from here
// :2:9: note: declared mutable here
// :4:15: note: crosses namespace boundary here
