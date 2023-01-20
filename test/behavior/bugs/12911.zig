const builtin = @import("builtin");

const Item = struct { field: u8 };
const Thing = struct {
    array: [1]Item,
};
test {
    _ = Thing{ .array = undefined };
}
