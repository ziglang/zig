const builtin = @import("builtin");
const c = @import("c.zig");

pub const CrossTarget = struct {
    arch: builtin.Arch,
    os: builtin.Os,
    environ: builtin.Environ,
};

pub const Target = union(enum) {
    Native,
    Cross: CrossTarget,

    pub fn oFileExt(self: *const Target) []const u8 {
        const environ = switch (self.*) {
            Target.Native => builtin.environ,
            Target.Cross => |t| t.environ,
        };
        return switch (environ) {
            builtin.Environ.msvc => ".obj",
            else => ".o",
        };
    }

    pub fn exeFileExt(self: *const Target) []const u8 {
        return switch (self.getOs()) {
            builtin.Os.windows => ".exe",
            else => "",
        };
    }

    pub fn getOs(self: *const Target) builtin.Os {
        return switch (self.*) {
            Target.Native => builtin.os,
            Target.Cross => |t| t.os,
        };
    }

    pub fn isDarwin(self: *const Target) bool {
        return switch (self.getOs()) {
            builtin.Os.ios, builtin.Os.macosx => true,
            else => false,
        };
    }

    pub fn isWindows(self: *const Target) bool {
        return switch (self.getOs()) {
            builtin.Os.windows => true,
            else => false,
        };
    }
};

pub fn initializeAll() void {
    c.LLVMInitializeAllTargets();
    c.LLVMInitializeAllTargetInfos();
    c.LLVMInitializeAllTargetMCs();
    c.LLVMInitializeAllAsmPrinters();
    c.LLVMInitializeAllAsmParsers();
}
