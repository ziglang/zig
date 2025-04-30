comptime {
    _ = @Struct(.auto, null, &.{}, &.{}, undefined);
}
comptime {
    _ = @Struct(.auto, null, &.{"foo"}, &.{undefined}, &.{.{}});
}

// error
//
// :2:42: error: use of undefined value here causes illegal behavior
// :5:41: error: use of undefined value here causes illegal behavior
