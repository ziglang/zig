var hidden: u32 = 0;
export fn updateHidden(val: u32) void {
    hidden = val;
}
export fn getHidden() u32 {
    return hidden;
}

const T = extern struct { x: u32 };

export var mut_val: f64 = 1.23;
export const const_val: T = .{ .x = 42 };
