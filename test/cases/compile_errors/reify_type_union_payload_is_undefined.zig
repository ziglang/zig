const Foo = @Struct(undefined);
comptime {
    _ = Foo;
}

// error
//
// :1:21: error: use of undefined value here causes illegal behavior
