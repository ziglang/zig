const Ty = struct {
	pub const A = void;
	pub const B = @Vector(2, u0);
	pub const C = u0;
	pub const D = enum (u0) {};
	pub const E = type;
	pub const F = 1;
	pub const G = 1.0;
	pub const H = undefined;
	pub const I = null;
	pub const J = .foo;
};
pub fn main() void {
	inline for (@typeInfo(Ty).Struct.decls) |d|{
		_ = @field(Ty, d.name);
	}
}

// compile
// output_mode=Exe
// backend=llvm
// target=x86_64-linux,x86_64-macos
//