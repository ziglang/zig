fn errorName(err: anyerror) [:0]const u8 {
    return @errorName(err);
}
export const error_name: *const anyopaque = &errorName;
