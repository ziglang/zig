const Foo = struct {
    x: i32,

    fn init(x: i32) Foo {
        return Foo{
            .x = x,
        };
    }
};

export fn f() void {
    const derp = Foo.init(3);

    derp.init();
}

// error
// backend=stage2
// target=native
//
// :14:9: error: no field or member function named 'init' in 'tmp.Foo'
// :1:13: note: struct declared here
// :4:5: note: 'init' is not a member function
