pub fn main() void {
    bar();
    foo();
    return;
}
fn foo() void {
    bar();
    bar();
    bar();
}
fn bar() void {}

// run
//
