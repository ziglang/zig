//! Because this file contains fields, it is a type which is intended to be instantiated, and so
//! is named in TitleCase instead of snake_case by convention.

foo: u32,
bar: u64,

/// `@This()` can be used to refer to this struct type. In files with fields, it is quite common to
/// name the type here, so it can be easily referenced by other declarations in this file.
const TopLevelFields = @This();

pub fn init(val: u32) TopLevelFields {
    return .{
        .foo = val,
        .bar = val * 10,
    };
}

// syntax
