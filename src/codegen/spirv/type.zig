//! This module models a SPIR-V Type. These are distinct from Zig types, with some types
//! which are not representable by Zig directly.

const std = @import("std");
const assert = std.debug.assert;
const Signedness = std.builtin.Signedness;
const Allocator = std.mem.Allocator;

const spec = @import("spec.zig");

pub const Type = extern union {
    tag_if_small_enough: Tag,
    ptr_otherwise: *Payload,

    /// A reference to another SPIR-V type.
    pub const Ref = enum(u32) { _ };

    pub fn initTag(comptime small_tag: Tag) Type {
        comptime assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = small_tag };
    }

    pub fn initPayload(pl: *Payload) Type {
        assert(@enumToInt(pl.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = pl };
    }

    pub fn int(arena: Allocator, signedness: Signedness, bits: u16) !Type {
        const bits_and_signedness = switch (signedness) {
            .signed => -@as(i32, bits),
            .unsigned => @as(i32, bits),
        };

        return switch (bits_and_signedness) {
            8 => initTag(.u8),
            16 => initTag(.u16),
            32 => initTag(.u32),
            64 => initTag(.u64),
            -8 => initTag(.i8),
            -16 => initTag(.i16),
            -32 => initTag(.i32),
            -64 => initTag(.i64),
            else => {
                const int_payload = try arena.create(Payload.Int);
                int_payload.* = .{
                    .width = bits,
                    .signedness = signedness,
                };
                return initPayload(&int_payload.base);
            },
        };
    }

    pub fn float(bits: u16) Type {
        return switch (bits) {
            16 => initTag(.f16),
            32 => initTag(.f32),
            64 => initTag(.f64),
            else => unreachable, // Enable more types if required.
        };
    }

    pub fn tag(self: Type) Tag {
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count) {
            return self.tag_if_small_enough;
        } else {
            return self.ptr_otherwise.tag;
        }
    }

    pub fn castTag(self: Type, comptime t: Tag) ?*t.Type() {
        if (@enumToInt(self.tag_if_small_enough) < Tag.no_payload_count)
            return null;

        if (self.ptr_otherwise.tag == t)
            return self.payload(t);

        return null;
    }

    /// Access the payload of a type directly.
    pub fn payload(self: Type, comptime t: Tag) *t.Type() {
        assert(self.tag() == t);
        return @fieldParentPtr(t.Type(), "base", self.ptr_otherwise);
    }

    /// Perform a shallow equality test, comparing two types while assuming that any child types
    /// are equal only if their references are equal.
    pub fn eqlShallow(a: Type, b: Type) bool {
        if (a.tag_if_small_enough == b.tag_if_small_enough)
            return true;

        const tag_a = a.tag();
        const tag_b = b.tag();
        if (tag_a != tag_b)
            return false;

        inline for (@typeInfo(Tag).Enum.fields) |field| {
            const t = @field(Tag, field.name);
            if (t == tag_a) {
                return eqlPayloads(t, a, b);
            }
        }

        unreachable;
    }

    /// Compare the payload of two compatible tags, given that we already know the tag of both types.
    fn eqlPayloads(comptime t: Tag, a: Type, b: Type) bool {
        switch (t) {
            .void,
            .bool,
            .sampler,
            .event,
            .device_event,
            .reserve_id,
            .queue,
            .pipe_storage,
            .named_barrier,
            .u8,
            .u16,
            .u32,
            .u64,
            .i8,
            .i16,
            .i32,
            .i64,
            .f16,
            .f32,
            .f64,
            => return true,
            .int,
            .vector,
            .matrix,
            .sampled_image,
            .array,
            .runtime_array,
            .@"opaque",
            .pointer,
            .pipe,
            .image,
            => return std.meta.eql(a.payload(t).*, b.payload(t).*),
            .@"struct" => {
                const struct_a = a.payload(.@"struct");
                const struct_b = b.payload(.@"struct");
                if (struct_a.members.len != struct_b.members.len)
                    return false;
                for (struct_a.members, 0..) |mem_a, i| {
                    if (!std.meta.eql(mem_a, struct_b.members[i]))
                        return false;
                }
                return true;
            },
            .function => {
                const fn_a = a.payload(.function);
                const fn_b = b.payload(.function);
                if (fn_a.return_type != fn_b.return_type)
                    return false;
                return std.mem.eql(Ref, fn_a.parameters, fn_b.parameters);
            },
        }
    }

    /// Perform a shallow hash, which hashes the reference value of child types instead of recursing.
    pub fn hashShallow(self: Type) u64 {
        var hasher = std.hash.Wyhash.init(0);
        const t = self.tag();
        std.hash.autoHash(&hasher, t);

        inline for (@typeInfo(Tag).Enum.fields) |field| {
            if (@field(Tag, field.name) == t) {
                switch (@field(Tag, field.name)) {
                    .void,
                    .bool,
                    .sampler,
                    .event,
                    .device_event,
                    .reserve_id,
                    .queue,
                    .pipe_storage,
                    .named_barrier,
                    .u8,
                    .u16,
                    .u32,
                    .u64,
                    .i8,
                    .i16,
                    .i32,
                    .i64,
                    .f16,
                    .f32,
                    .f64,
                    => {},
                    else => self.hashPayload(@field(Tag, field.name), &hasher),
                }
            }
        }

        return hasher.final();
    }

    /// Perform a shallow hash, given that we know the tag of the field ahead of time.
    fn hashPayload(self: Type, comptime t: Tag, hasher: *std.hash.Wyhash) void {
        const fields = @typeInfo(t.Type()).Struct.fields;
        const pl = self.payload(t);
        comptime assert(std.mem.eql(u8, fields[0].name, "base"));
        inline for (fields[1..]) |field| { // Skip the 'base' field.
            std.hash.autoHashStrat(hasher, @field(pl, field.name), .DeepRecursive);
        }
    }

    /// Hash context that hashes and compares types in a shallow fashion, useful for type caches.
    pub const ShallowHashContext32 = struct {
        pub fn hash(self: @This(), t: Type) u32 {
            _ = self;
            return @truncate(u32, t.hashShallow());
        }
        pub fn eql(self: @This(), a: Type, b: Type, b_index: usize) bool {
            _ = self;
            _ = b_index;
            return a.eqlShallow(b);
        }
    };

    /// Return the reference to any child type. Asserts the type is one of:
    /// - Vectors
    /// - Matrices
    /// - Images
    /// - SampledImages,
    /// - Arrays
    /// - RuntimeArrays
    /// - Pointers
    pub fn childType(self: Type) Ref {
        return switch (self.tag()) {
            .vector => self.payload(.vector).component_type,
            .matrix => self.payload(.matrix).column_type,
            .image => self.payload(.image).sampled_type,
            .sampled_image => self.payload(.sampled_image).image_type,
            .array => self.payload(.array).element_type,
            .runtime_array => self.payload(.runtime_array).element_type,
            .pointer => self.payload(.pointer).child_type,
            else => unreachable,
        };
    }

    pub fn isInt(self: Type) bool {
        return switch (self.tag()) {
            .u8,
            .u16,
            .u32,
            .u64,
            .i8,
            .i16,
            .i32,
            .i64,
            .int,
            => true,
            else => false,
        };
    }

    pub fn isFloat(self: Type) bool {
        return switch (self.tag()) {
            .f16, .f32, .f64 => true,
            else => false,
        };
    }

    /// Returns the number of bits that make up an int or float type.
    /// Asserts type is either int or float.
    pub fn intFloatBits(self: Type) u16 {
        return switch (self.tag()) {
            .u8, .i8 => 8,
            .u16, .i16, .f16 => 16,
            .u32, .i32, .f32 => 32,
            .u64, .i64, .f64 => 64,
            .int => self.payload(.int).width,
            else => unreachable,
        };
    }

    /// Returns the signedness of an integer type.
    /// Asserts that the type is an int.
    pub fn intSignedness(self: Type) Signedness {
        return switch (self.tag()) {
            .u8, .u16, .u32, .u64 => .unsigned,
            .i8, .i16, .i32, .i64 => .signed,
            .int => self.payload(.int).signedness,
            else => unreachable,
        };
    }

    pub const Tag = enum(usize) {
        void,
        bool,
        sampler,
        event,
        device_event,
        reserve_id,
        queue,
        pipe_storage,
        named_barrier,
        u8,
        u16,
        u32,
        u64,
        i8,
        i16,
        i32,
        i64,
        f16,
        f32,
        f64,

        // After this, the tag requires a payload.
        int,
        vector,
        matrix,
        image,
        sampled_image,
        array,
        runtime_array,
        @"struct",
        @"opaque",
        pointer,
        function,
        pipe,

        pub const last_no_payload_tag = Tag.f64;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(comptime t: Tag) type {
            return switch (t) {
                .void,
                .bool,
                .sampler,
                .event,
                .device_event,
                .reserve_id,
                .queue,
                .pipe_storage,
                .named_barrier,
                .u8,
                .u16,
                .u32,
                .u64,
                .i8,
                .i16,
                .i32,
                .i64,
                .f16,
                .f32,
                .f64,
                => @compileError("Type Tag " ++ @tagName(t) ++ " has no payload"),
                .int => Payload.Int,
                .vector => Payload.Vector,
                .matrix => Payload.Matrix,
                .image => Payload.Image,
                .sampled_image => Payload.SampledImage,
                .array => Payload.Array,
                .runtime_array => Payload.RuntimeArray,
                .@"struct" => Payload.Struct,
                .@"opaque" => Payload.Opaque,
                .pointer => Payload.Pointer,
                .function => Payload.Function,
                .pipe => Payload.Pipe,
            };
        }
    };

    pub const Payload = struct {
        tag: Tag,

        pub const Int = struct {
            base: Payload = .{ .tag = .int },
            width: u16,
            signedness: Signedness,
        };

        pub const Vector = struct {
            base: Payload = .{ .tag = .vector },
            component_type: Ref,
            component_count: u32,
        };

        pub const Matrix = struct {
            base: Payload = .{ .tag = .matrix },
            column_type: Ref,
            column_count: u32,
        };

        pub const Image = struct {
            base: Payload = .{ .tag = .image },
            sampled_type: Ref,
            dim: spec.Dim,
            depth: enum(u2) {
                no = 0,
                yes = 1,
                maybe = 2,
            },
            arrayed: bool,
            multisampled: bool,
            sampled: enum(u2) {
                known_at_runtime = 0,
                with_sampler = 1,
                without_sampler = 2,
            },
            format: spec.ImageFormat,
            access_qualifier: ?spec.AccessQualifier,
        };

        pub const SampledImage = struct {
            base: Payload = .{ .tag = .sampled_image },
            image_type: Ref,
        };

        pub const Array = struct {
            base: Payload = .{ .tag = .array },
            element_type: Ref,
            /// Note: Must be emitted as constant, not as literal!
            length: u32,
            /// Type has the 'ArrayStride' decoration.
            /// If zero, no stride is present.
            array_stride: u32 = 0,
        };

        pub const RuntimeArray = struct {
            base: Payload = .{ .tag = .runtime_array },
            element_type: Ref,
            /// Type has the 'ArrayStride' decoration.
            /// If zero, no stride is present.
            array_stride: u32 = 0,
        };

        pub const Struct = struct {
            base: Payload = .{ .tag = .@"struct" },
            members: []Member,
            name: []const u8 = "",
            decorations: StructDecorations = .{},

            /// Extra information for decorations, packed for efficiency. Fields are stored sequentially by
            /// order of the `members` slice and `MemberDecorations` struct.
            member_decoration_extra: []u32 = &.{},

            pub const Member = struct {
                ty: Ref,
                name: []const u8 = "",
                offset: MemberOffset = .none,
                decorations: MemberDecorations = .{},
            };

            pub const MemberOffset = enum(u32) { none = 0xFFFF_FFFF, _ };

            pub const StructDecorations = packed struct {
                /// Type has the 'Block' decoration.
                block: bool = false,
                /// Type has the 'BufferBlock' decoration.
                buffer_block: bool = false,
                /// Type has the 'GLSLShared' decoration.
                glsl_shared: bool = false,
                /// Type has the 'GLSLPacked' decoration.
                glsl_packed: bool = false,
                /// Type has the 'CPacked' decoration.
                c_packed: bool = false,
            };

            pub const MemberDecorations = packed struct {
                /// Matrix layout for (arrays of) matrices. If this field is not .none,
                /// then there is also an extra field containing the matrix stride corresponding
                /// to the 'MatrixStride' decoration.
                matrix_layout: enum(u2) {
                    /// Member has the 'RowMajor' decoration. The member type
                    /// must be a matrix or an array of matrices.
                    row_major,
                    /// Member has the 'ColMajor' decoration. The member type
                    /// must be a matrix or an array of matrices.
                    col_major,
                    /// Member is not a matrix or array of matrices.
                    none,
                } = .none,

                // Regular decorations, these do not imply extra fields.

                /// Member has the 'NoPerspective' decoration.
                no_perspective: bool = false,
                /// Member has the 'Flat' decoration.
                flat: bool = false,
                /// Member has the 'Patch' decoration.
                patch: bool = false,
                /// Member has the 'Centroid' decoration.
                centroid: bool = false,
                /// Member has the 'Sample' decoration.
                sample: bool = false,
                /// Member has the 'Invariant' decoration.
                /// Note: requires parent struct to have 'Block'.
                invariant: bool = false,
                /// Member has the 'Volatile' decoration.
                @"volatile": bool = false,
                /// Member has the 'Coherent' decoration.
                coherent: bool = false,
                /// Member has the 'NonWritable' decoration.
                non_writable: bool = false,
                /// Member has the 'NonReadable' decoration.
                non_readable: bool = false,

                // The following decorations all imply extra field(s).

                /// Member has the 'BuiltIn' decoration.
                /// This decoration has an extra field of type `spec.BuiltIn`.
                /// Note: If any member of a struct has the BuiltIn decoration, all members must have one.
                /// Note: Each builtin may only be reachable once for a particular entry point.
                /// Note: The member type may be constrained by a particular built-in, defined in the client API specification.
                builtin: bool = false,
                /// Member has the 'Stream' decoration.
                /// This member has an extra field of type `u32`.
                stream: bool = false,
                /// Member has the 'Location' decoration.
                /// This member has an extra field of type `u32`.
                location: bool = false,
                /// Member has the 'Component' decoration.
                /// This member has an extra field of type `u32`.
                component: bool = false,
                /// Member has the 'XfbBuffer' decoration.
                /// This member has an extra field of type `u32`.
                xfb_buffer: bool = false,
                /// Member has the 'XfbStride' decoration.
                /// This member has an extra field of type `u32`.
                xfb_stride: bool = false,
                /// Member has the 'UserSemantic' decoration.
                /// This member has an extra field of type `[]u8`, which is encoded
                /// by an `u32` containing the number of chars exactly, and then the string padded to
                /// a multiple of 4 bytes with zeroes.
                user_semantic: bool = false,
            };
        };

        pub const Opaque = struct {
            base: Payload = .{ .tag = .@"opaque" },
            name: []u8,
        };

        pub const Pointer = struct {
            base: Payload = .{ .tag = .pointer },
            storage_class: spec.StorageClass,
            child_type: Ref,
            /// Type has the 'ArrayStride' decoration.
            /// This is valid for pointers to elements of an array.
            /// If zero, no stride is present.
            array_stride: u32 = 0,
            /// If nonzero, type has the 'Alignment' decoration.
            alignment: u32 = 0,
            /// Type has the 'MaxByteOffset' decoration.
            max_byte_offset: ?u32 = null,
        };

        pub const Function = struct {
            base: Payload = .{ .tag = .function },
            return_type: Ref,
            parameters: []Ref,
        };

        pub const Pipe = struct {
            base: Payload = .{ .tag = .pipe },
            qualifier: spec.AccessQualifier,
        };
    };
};
