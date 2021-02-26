pub fn main() void {
    if (@import("buildpkgs").has("foo")) {
        @compileError("calling buildpkgs.has outside of build.zig should be a compile error");
    }
}
