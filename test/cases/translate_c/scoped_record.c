void foo() {
	struct Foo {
		int A;
		int B;
		int C;
	};
	struct Foo a = {0};
	{
		struct Foo {
			int A;
			int B;
			int C;
		};
		struct Foo a = {0};
	}
}

// translate-c
// c_frontend=clang
//
// pub export fn foo() void {
//     const struct_Foo = extern struct {
//         A: c_int = @import("std").mem.zeroes(c_int),
//         B: c_int = @import("std").mem.zeroes(c_int),
//         C: c_int = @import("std").mem.zeroes(c_int),
//     };
//     _ = &struct_Foo;
//     var a: struct_Foo = struct_Foo{
//         .A = @as(c_int, 0),
//         .B = 0,
//         .C = 0,
//     };
//     _ = &a;
//     {
//         const struct_Foo_1 = extern struct {
//             A: c_int = @import("std").mem.zeroes(c_int),
//             B: c_int = @import("std").mem.zeroes(c_int),
//             C: c_int = @import("std").mem.zeroes(c_int),
//         };
//         _ = &struct_Foo_1;
//         var a_2: struct_Foo_1 = struct_Foo_1{
//             .A = @as(c_int, 0),
//             .B = 0,
//             .C = 0,
//         };
//         _ = &a_2;
//     }
// }

