const Foo = struct { i: i32 };
const Bar = struct { j: i32 };

pub fn helper(_: Foo, _: Bar) void {}

comptime {
    helper(Bar{ .j = 10 }, Bar{ .j = 10 });
    helper(Bar{ .i = 10 }, Bar{ .j = 10 });
}

// error
// backend=stage2
// target=native
//
// :7:15: error: expected type 'tmp.Foo', found 'tmp.Bar'
// :2:13: note: struct declared here
// :1:13: note: struct declared here
// :4:18: note: parameter type declared here
