usingnamespace @import("other.zig");

pub var saw_bar_function = false;
pub fn bar_function() void {
    if (@This().foo_function()) {
        saw_bar_function = true;
    }
}
