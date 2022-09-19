export fn foo() void {
    var a: f16 = 2.2;
    // this will pull-in compiler-rt
    var b = @trunc(a);
    _ = b;
}
