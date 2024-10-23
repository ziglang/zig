foo: u32,
bar: u32,
qux: u32,

const foo = 123;

var bar: u8 = undefined;
fn bar() void {}

// error
//
// :1:1: error: duplicate struct member name 'foo'
// :5:7: note: duplicate name here
// :1:1: note: struct declared here
// :2:1: error: duplicate struct member name 'bar'
// :7:5: note: duplicate name here
// :8:4: note: duplicate name here
// :1:1: note: struct declared here
