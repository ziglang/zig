//! This module models a SPIR-V Type. These are distinct from Zig types, with some types
//! which are not representable by Zig directly.

const std = @import("std");
const assert = std.debug.assert;

const spec = @import("spec.zig");

pub const Type = extern union {
    tag_if_small_enough: Tag,
    ptr_otherwise: *Payload,

    /// A reference to another SPIR-V type.
    pub const Ref = usize;

    pub fn initTag(comptime small_tag: Tag) Type {
        comptime assert(@enumToInt(small_tag) < Tag.no_payload_count);
        return .{ .tag_if_small_enough = small_tag };
    }

    pub fn initPayload(pl: *Payload) Type {
        assert(@enumToInt(pl.tag) >= Tag.no_payload_count);
        return .{ .ptr_otherwise = pl };
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
            => return true,
            .int,
            .float,
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
                for (struct_a.members) |mem_a, i| {
                    if (!std.meta.eql(mem_a, struct_b.members[i]))
                        return false;
                }
                return true;
            },
            .@"function" => {
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

        // After this, the tag requires a payload.
        int,
        float,
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

        pub const last_no_payload_tag = Tag.named_barrier;
        pub const no_payload_count = @enumToInt(last_no_payload_tag) + 1;

        pub fn Type(comptime t: Tag) type {
            return switch (t) {
                .void, .bool, .sampler, .event, .device_event, .reserve_id, .queue, .pipe_storage, .named_barrier => @compileError("Type Tag " ++ @tagName(t) ++ " has no payload"),
                .int => Payload.Int,
                .float => Payload.Float,
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
            width: u32,
            signedness: std.builtin.Signedness,
        };

        pub const Float = struct {
            base: Payload = .{ .tag = .float },
            width: u32,
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
            array_stride: u32,
        };

        pub const RuntimeArray = struct {
            base: Payload = .{ .tag = .runtime_array },
            element_type: Ref,
            /// Type has the 'ArrayStride' decoration.
            /// If zero, no stride is present.
            array_stride: u32,
        };

        pub const Struct = struct {
            base: Payload = .{ .tag = .@"struct" },
            members: []Member,
            decorations: StructDecorations,

            /// Extra information for decorations, packed for efficiency. Fields are stored sequentially by
            /// order of the `members` slice and `MemberDecorations` struct.
            member_decoration_extra: []u32,

            pub const Member = struct {
                ty: Ref,
                offset: u32,
                decorations: MemberDecorations,
            };

            pub const StructDecorations = packed struct {
                /// Type has the 'Block' decoration.
                block: bool,
                /// Type has the 'BufferBlock' decoration.
                buffer_block: bool,
                /// Type has the 'GLSLShared' decoration.
                glsl_shared: bool,
                /// Type has the 'GLSLPacked' decoration.
                glsl_packed: bool,
                /// Type has the 'CPacked' decoration.
                c_packed: bool,
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
                },

                // Regular decorations, these do not imply extra fields.

                /// Member has the 'NoPerspective' decoration.
                no_perspective: bool,
                /// Member has the 'Flat' decoration.
                flat: bool,
                /// Member has the 'Patch' decoration.
                patch: bool,
                /// Member has the 'Centroid' decoration.
                centroid: bool,
                /// Member has the 'Sample' decoration.
                sample: bool,
                /// Member has the 'Invariant' decoration.
                /// Note: requires parent struct to have 'Block'.
                invariant: bool,
                /// Member has the 'Volatile' decoration.
                @"volatile": bool,
                /// Member has the 'Coherent' decoration.
                coherent: bool,
                /// Member has the 'NonWritable' decoration.
                non_writable: bool,
                /// Member has the 'NonReadable' decoration.
                non_readable: bool,

                // The following decorations all imply extra field(s).

                /// Member has the 'BuiltIn' decoration.
                /// This decoration has an extra field of type `spec.BuiltIn`.
                /// Note: If any member of a struct has the BuiltIn decoration, all members must have one.
                /// Note: Each builtin may only be reachable once for a particular entry point.
                /// Note: The member type may be constrained by a particular built-in, defined in the client API specification.
                builtin: bool,
                /// Member has the 'Stream' decoration.
                /// This member has an extra field of type `u32`.
                stream: bool,
                /// Member has the 'Location' decoration.
                /// This member has an extra field of type `u32`.
                location: bool,
                /// Member has the 'Component' decoration.
                /// This member has an extra field of type `u32`.
                component: bool,
                /// Member has the 'XfbBuffer' decoration.
                /// This member has an extra field of type `u32`.
                xfb_buffer: bool,
                /// Member has the 'XfbStride' decoration.
                /// This member has an extra field of type `u32`.
                xfb_stride: bool,
                /// Member has the 'UserSemantic' decoration.
                /// This member has an extra field of type `[]u8`, which is encoded
                /// by an `u32` containing the number of chars exactly, and then the string padded to
                /// a multiple of 4 bytes with zeroes.
                user_semantic: bool,
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
            array_stride: u32,
            /// Type has the 'Alignment' decoration.
            alignment: ?u32,
            /// Type has the 'MaxByteOffset' decoration.
            max_byte_offset: ?u32,
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
