pub const A = extern struct {
    field: c_int,
};

pub extern fn issue529(?*A) void;
