export fn inconsistentChildType() void {
    var x: ?i32 = undefined;
    const y: comptime_int = 10;
    _ = (x == y);
}

export fn optionalToOptional() void {
    var x: ?i32 = undefined;
    var y: ?i32 = undefined;
    _ = (x == y);
}

export fn optionalVector() void {
    var x: ?@Vector(10, i32) = undefined;
    var y: @Vector(10, i32) = undefined;
    _ = (x == y);
}

export fn invalidChildType() void {
    var x: ?[3]i32 = undefined;
    var y: [3]i32 = undefined;
    _ = (x == y);
}

// compare optional to non-optional with invalid types
//
// :4:12: error: cannot compare types '?i32' and 'comptime_int'
// :4:12: note: optional child type 'i32' must be the same as non-optional type 'comptime_int'
// :10:12: error: cannot compare types '?i32' and '?i32'
// :10:12: note: optional to optional comparison is only supported for optional pointer types
// :16:12: error: TODO add comparison of optional vector
// :22:12: error: cannot compare types '?[3]i32' and '[3]i32'
// :22:12: note: operator not supported for type '[3]i32'
