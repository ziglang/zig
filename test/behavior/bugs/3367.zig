const builtin = @import("builtin");
const Foo = struct {
    usingnamespace Mixin;
};

const Mixin = struct {
    pub fn two(self: Foo) void {
        _ = self;
    }
};

test "container member access usingnamespace decls" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var foo = Foo{};
    foo.two();
}
