pub fn Interface() type {
    const Impl = @OpaqueType();

    return struct {
        const Self = @This();

        impl: *Impl,

        pub fn init(ptr: var) Self {
            const T = @typeOf(ptr);
            if (@alignOf(T) == 0) @compileError("0-Bit implementations can't be casted (and casting is unnecessary anyway, use null)");
            // This @ptrCast keeps causing "cast discards const qualifier" so it cascaded the const everywhere...
            return Self{ .impl = @ptrCast(*Impl, ptr) };
        }

        pub fn implCast(self: *const Self, comptime T: type) *T {
            if (@alignOf(T) == 0) @compileError("0-Bit implementations can't be casted (and casting is unnecessary anyway)");
            const aligned = @alignCast(@alignOf(T), self.impl);
            return @ptrCast(*T, aligned);
        }
    };
}
