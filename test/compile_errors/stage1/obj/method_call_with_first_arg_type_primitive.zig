const Foo = struct {
    x: i32,

    fn init(x: i32) Foo {
        return Foo {
            .x = x,
        };
    }
};

export fn f() void {
    const derp = Foo.init(3);

    derp.init();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:14:5: error: expected type 'i32', found 'Foo'
