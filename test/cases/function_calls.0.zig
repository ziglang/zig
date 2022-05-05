pub fn main() void {
    foo();
    bar();
}
fn foo() void {
    bar();
    bar();
}
fn bar() void {}

// run
//
