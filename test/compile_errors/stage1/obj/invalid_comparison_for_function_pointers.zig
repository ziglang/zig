fn foo() void {}
const invalid = foo > foo;

export fn entry() usize { return @sizeOf(@TypeOf(invalid)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: operator not allowed for type 'fn() void'
