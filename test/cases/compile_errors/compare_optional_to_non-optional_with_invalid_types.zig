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
export fn optionalVector2() void {
    var x: ?@Vector(10, i32) = undefined;
    var y: @Vector(11, i32) = undefined;
    _ = (x == y);
}
export fn invalidChildType() void {
    var x: ?[3]i32 = undefined;
    var y: [3]i32 = undefined;
    _ = (x == y);
}

// error
// backend=llvm
// target=native
//
// :4:12: error: incompatible types: '?i32' and 'comptime_int'
// :4:10: note: type '?i32' here
// :4:15: note: type 'comptime_int' here
// :19:12: error: incompatible types: '?@Vector(10, i32)' and '@Vector(11, i32)'
// :19:10: note: type '?@Vector(10, i32)' here
// :19:15: note: type '@Vector(11, i32)' here
// :24:12: error: operator == not allowed for type '?[3]i32'
