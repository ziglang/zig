test "@Type should resolve its children types" {
    const sparse = enum(u2) { a, b, c };
    const dense = enum(u2) { a, b, c, d };

    comptime var sparse_info = @typeInfo(anyerror!sparse);
    sparse_info.ErrorUnion.payload = dense;
    const B = @Type(sparse_info);
    _ = B;
}
