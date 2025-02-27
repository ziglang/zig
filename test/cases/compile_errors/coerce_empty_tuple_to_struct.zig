const empty = .{};

const Foo = struct {};
const foo: Foo = empty;

const Bar = struct { a: u32 };
const bar: Bar = empty;

comptime {
    _ = foo;
}
comptime {
    _ = bar;
}

// error
//
// :4:18: error: expected type 'tmp.Foo', found '@TypeOf(.{})'
// :3:13: note: struct declared here
// :7:18: error: expected type 'tmp.Bar', found '@TypeOf(.{})'
// :6:13: note: struct declared here
