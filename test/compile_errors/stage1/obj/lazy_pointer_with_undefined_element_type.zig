export fn foo() void {
    comptime var T: type = undefined;
    const S = struct { x: *T };
    const I = @typeInfo(S);
    _ = I;
}

// lazy pointer with undefined element type
//
// :3:28: error: use of undefined value here causes undefined behavior
