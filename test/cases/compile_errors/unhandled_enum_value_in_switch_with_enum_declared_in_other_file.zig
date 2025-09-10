const std = @import("std");

pub export fn entry1() void {
    const alignment: std.fmt.Alignment = .center;
    switch (alignment) {}
}

// error
// backend=stage2
// target=native
//
// :5:5: error: switch must handle all possibilities
// :?:?: note: unhandled enumeration value: 'left'
// :?:?: note: unhandled enumeration value: 'center'
// :?:?: note: unhandled enumeration value: 'right'
// :?:?: note: enum 'fmt.Alignment' declared here
