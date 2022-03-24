const Foo = struct {
    a: i32,
    b: i32,

    fn member_a(foo: *const Foo) i32 {
        return foo.a;
    }
    fn member_b(foo: *const Foo) i32 {
        return foo.b;
    }
};

const member_fn_type = @TypeOf(Foo.member_a);
const members = [_]member_fn_type {
    Foo.member_a,
    Foo.member_b,
};

fn f(foo: *const Foo, index: usize) void {
    const result = members[index]();
    _ = foo;
    _ = result;
}

export fn entry() usize { return @sizeOf(@TypeOf(f)); }

// missing function call param
//
// tmp.zig:20:34: error: expected 1 argument(s), found 0
