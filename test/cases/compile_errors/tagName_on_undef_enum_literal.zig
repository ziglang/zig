comptime {
    const undef: @EnumLiteral() = undefined;
    _ = @tagName(undef);
}

// error
//
// :3:18: error: use of undefined value here causes illegal behavior
