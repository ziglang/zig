export fn builtinCallBoolFunctionInlineWithVoid() void {
    @call(.always_inline, boolFunction, .{{}});
}

fn boolFunction(_: bool) void {}

// error
//
// :2:43: error: expected type 'bool', found 'void'
// :5:20: note: parameter type declared here
