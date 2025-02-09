comptime {
    const undef: @Type(.enum_literal) = undefined;
    _ = @tagName(undef);
}

// error
//
// :3:18: error: use of undefined value here causes undefined behavior
