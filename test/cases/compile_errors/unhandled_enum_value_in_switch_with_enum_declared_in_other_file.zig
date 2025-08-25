const std = @import("std");

pub export fn entry1() void {
    const order: std.math.Order = .lt;
    switch (order) {}
}

// error
// backend=stage2
// target=native
//
// :5:5: error: switch must handle all possibilities
// :?:?: note: unhandled enumeration value: 'gt'
// :?:?: note: unhandled enumeration value: 'lt'
// :?:?: note: unhandled enumeration value: 'eq'
// :?:?: note: enum 'math.Order' declared here
