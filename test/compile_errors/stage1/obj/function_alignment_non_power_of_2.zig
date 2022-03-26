extern fn foo() align(3) void;
export fn entry() void { return foo(); }

// function alignment non power of 2
//
// tmp.zig:1:23: error: alignment value 3 is not a power of 2
