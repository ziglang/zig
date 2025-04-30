const Untagged = @Union(.auto, null, &.{"foo"}, &.{opaque {}}, &.{.{}});
export fn entry() usize {
    return @sizeOf(Untagged);
}

// error
//
// :1:49: error: opaque types have unknown size and therefore cannot be directly embedded in unions
// :1:52: note: opaque declared here
