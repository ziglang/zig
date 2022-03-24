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

// result location incompatibility mismatching handle_is_ptr
//
// tmp.zig:3:36: error: cannot convert optional to payload type. consider using `.?`, `orelse`, or `if`. expected type 'i32', found '?i32'
