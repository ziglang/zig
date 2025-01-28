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
// :4:9: error: expected 'a string literal', found invalid bytes
// :4:11: note: invalid byte: '\t'
