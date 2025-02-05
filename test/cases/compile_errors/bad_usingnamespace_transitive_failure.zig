//! The full test name would be:
//! struct field type resolution marks transitive error from bad usingnamespace in @typeInfo call from non-initial field type
//!
//! This test is rather esoteric. It's ensuring that errors triggered by `@typeInfo` analyzing
//! a bad `usingnamespace` correctly trigger transitive errors when analyzed by struct field type
//! resolution, meaning we don't incorrectly analyze code past the uses of `S`.

const S = struct {
    ok: u32,
    bad: @typeInfo(T),
};

const T = struct {
    pub usingnamespace @compileError("usingnamespace analyzed");
};

comptime {
    const a: S = .{ .ok = 123, .bad = undefined };
    _ = a;
    @compileError("should not be reached");
}

comptime {
    const b: S = .{ .ok = 123, .bad = undefined };
    _ = b;
    @compileError("should not be reached");
}

// error
//
// :14:24: error: usingnamespace analyzed
