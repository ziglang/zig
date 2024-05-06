fn CreateType() !type {
    return struct {};
}
const MyType = CreateType();
const TestType = struct {
    my_type: MyType,
};
comptime {
    _ = @sizeOf(TestType) + 1;
}

// error
//
//:6:14: error: expected type 'type', found 'error{}!type'
//:6:14: note: cannot convert error union to payload type
//:6:14: note: consider using 'try', 'catch', or 'if'
