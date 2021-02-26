//! Currently the user MUST specify comptime when calling "buildpkgs.has"
//! until https://github.com/ziglang/zig/issues/425 is implemented.
//! This build.zig file tries to call "buildpkgs.has" without comptime and the
//! test is to make sure it produces a compile error.
//!
//! Note that the reason why "buildpkgs.has" must be evaluated at comptime is
//! because it will always surround an @import statement.  The problem is
//! that if they forget to add "comptime" to their call, then their build.zig
//! file will "sometimes work" so long as they are building with the necessary
//! packages configured, but then it will fail once the @import is missing
//! which defeats the whole purpose of providing "buildpkgs.has" in the first place.
//!
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // This should be a compile error because it's not marked as comptime
    if (@import("buildpkgs").has("androidbuild")) {
        const androidbuild = @import("androidbuild");
        androidbuild.makeApk(b);
    }
}
