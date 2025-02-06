export fn entry() void {
    const foo =
        \\const S = struct {
        \\	// hello
        \\}
    ;
    _ = foo;
}
// error
// backend=stage2
// target=native
//
// :4:11: error: string literal contains invalid byte: '\t'
