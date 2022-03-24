fn foo() !void {
    return anyerror.Foo;
}
export fn entry() void {
    foo() catch 0;
}

// missing result type for phi node
//
// tmp.zig:5:17: error: integer value 0 cannot be coerced to type 'void'
