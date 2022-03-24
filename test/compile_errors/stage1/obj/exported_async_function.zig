export fn foo() callconv(.Async) void {}

// exported async function
//
// tmp.zig:1:1: error: exported function cannot be async
