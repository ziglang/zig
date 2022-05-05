pub fn main() void {
    bar();
    foo();
    foo();
    bar();
    foo();
    bar();
}
fn foo() void {
    bar();
}
fn bar() void {}

// run
//
