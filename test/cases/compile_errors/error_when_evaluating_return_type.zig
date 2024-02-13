const Foo = struct {
    map: @as(i32, i32),

    fn init() Foo {
        return undefined;
    }
};
export fn entry() void {
    const rule_set = try Foo.init();
    _ = rule_set;
}

// error
// backend=stage2
// target=native
//
// :2:19: error: expected type 'i32', found 'type'
