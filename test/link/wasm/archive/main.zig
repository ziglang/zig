export fn foo() void {
    var a: f16 = 2.2;
    _ = &a;
    // this will pull-in compiler-rt
    const b = @trunc(a);
    _ = b;
}
