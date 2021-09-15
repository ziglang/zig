// purposefully conflicting function with main source file
// but it's private so it should be OK
fn privateFunction() bool {
    return false;
}

pub fn printText() bool {
    return privateFunction();
}

pub var saw_foo_function = false;
pub fn foo_function() void {
    saw_foo_function = true;
}
