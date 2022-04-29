export fn foo() callconv(.Async) void {}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:1: error: exported function cannot be async
