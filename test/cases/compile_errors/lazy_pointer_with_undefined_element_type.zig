export fn foo() void {
    comptime var T: type = undefined;
    _ = &T;
    const S = struct { x: *T };
    const I = @typeInfo(S);
    _ = I;
}

// error
//
// :4:28: error: use of undefined value here causes illegal behavior
