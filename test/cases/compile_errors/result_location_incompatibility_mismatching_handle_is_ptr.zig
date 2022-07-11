export fn entry() void {
    var damn = Container{
        .not_optional = getOptional(),
    };
    _ = damn;
}
pub fn getOptional() ?i32 {
    return 0;
}
pub const Container = struct {
    not_optional: i32,
};

// error
// backend=stage2
// target=native
//
// :3:36: error: expected type 'i32', found '?i32'
// :3:36: note: cannot convert optional to payload type
// :3:36: note: consider using `.?`, `orelse`, or `if`
