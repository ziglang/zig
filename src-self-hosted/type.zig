const builtin = @import("builtin");
const Scope = @import("scope.zig").Scope;
const Module = @import("module.zig").Module;
const Value = @import("value.zig").Value;

pub const Type = struct {
    base: Value,
    id: Id,

    pub const Id = builtin.TypeId;

    pub fn destroy(base: *Type, module: *Module) void {
        switch (base.id) {
            Id.Struct => @fieldParentPtr(Struct, "base", base).destroy(module),
            Id.Fn => @fieldParentPtr(Fn, "base", base).destroy(module),
            Id.Type => @fieldParentPtr(MetaType, "base", base).destroy(module),
            Id.Void => @fieldParentPtr(Void, "base", base).destroy(module),
            Id.Bool => @fieldParentPtr(Bool, "base", base).destroy(module),
            Id.NoReturn => @fieldParentPtr(NoReturn, "base", base).destroy(module),
            Id.Int => @fieldParentPtr(Int, "base", base).destroy(module),
            Id.Float => @fieldParentPtr(Float, "base", base).destroy(module),
            Id.Pointer => @fieldParentPtr(Pointer, "base", base).destroy(module),
            Id.Array => @fieldParentPtr(Array, "base", base).destroy(module),
            Id.ComptimeFloat => @fieldParentPtr(ComptimeFloat, "base", base).destroy(module),
            Id.ComptimeInt => @fieldParentPtr(ComptimeInt, "base", base).destroy(module),
            Id.Undefined => @fieldParentPtr(Undefined, "base", base).destroy(module),
            Id.Null => @fieldParentPtr(Null, "base", base).destroy(module),
            Id.Optional => @fieldParentPtr(Optional, "base", base).destroy(module),
            Id.ErrorUnion => @fieldParentPtr(ErrorUnion, "base", base).destroy(module),
            Id.ErrorSet => @fieldParentPtr(ErrorSet, "base", base).destroy(module),
            Id.Enum => @fieldParentPtr(Enum, "base", base).destroy(module),
            Id.Union => @fieldParentPtr(Union, "base", base).destroy(module),
            Id.Namespace => @fieldParentPtr(Namespace, "base", base).destroy(module),
            Id.Block => @fieldParentPtr(Block, "base", base).destroy(module),
            Id.BoundFn => @fieldParentPtr(BoundFn, "base", base).destroy(module),
            Id.ArgTuple => @fieldParentPtr(ArgTuple, "base", base).destroy(module),
            Id.Opaque => @fieldParentPtr(Opaque, "base", base).destroy(module),
            Id.Promise => @fieldParentPtr(Promise, "base", base).destroy(module),
        }
    }

    pub const Struct = struct {
        base: Type,
        decls: *Scope.Decls,

        pub fn destroy(self: *Struct, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Fn = struct {
        base: Type,

        pub fn create(module: *Module) !*Fn {
            return module.a().create(Fn{
                .base = Type{
                    .base = Value{
                        .id = Value.Id.Type,
                        .typeof = &MetaType.get(module).base,
                        .ref_count = 1,
                    },
                    .id = builtin.TypeId.Fn,
                },
            });
        }

        pub fn destroy(self: *Fn, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const MetaType = struct {
        base: Type,
        value: *Type,

        /// Adds 1 reference to the resulting type
        pub fn get(module: *Module) *MetaType {
            module.meta_type.base.base.ref();
            return module.meta_type;
        }

        pub fn destroy(self: *MetaType, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Void = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(module: *Module) *Void {
            module.void_type.base.base.ref();
            return module.void_type;
        }

        pub fn destroy(self: *Void, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Bool = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(module: *Module) *Bool {
            module.bool_type.base.base.ref();
            return module.bool_type;
        }

        pub fn destroy(self: *Bool, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const NoReturn = struct {
        base: Type,

        /// Adds 1 reference to the resulting type
        pub fn get(module: *Module) *NoReturn {
            module.noreturn_type.base.base.ref();
            return module.noreturn_type;
        }

        pub fn destroy(self: *NoReturn, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Int = struct {
        base: Type,

        pub fn destroy(self: *Int, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Float = struct {
        base: Type,

        pub fn destroy(self: *Float, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const Pointer = struct {
        base: Type,

        pub fn destroy(self: *Pointer, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const Array = struct {
        base: Type,

        pub fn destroy(self: *Array, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const ComptimeFloat = struct {
        base: Type,

        pub fn destroy(self: *ComptimeFloat, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const ComptimeInt = struct {
        base: Type,

        pub fn destroy(self: *ComptimeInt, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const Undefined = struct {
        base: Type,

        pub fn destroy(self: *Undefined, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const Null = struct {
        base: Type,

        pub fn destroy(self: *Null, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const Optional = struct {
        base: Type,

        pub fn destroy(self: *Optional, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const ErrorUnion = struct {
        base: Type,

        pub fn destroy(self: *ErrorUnion, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const ErrorSet = struct {
        base: Type,

        pub fn destroy(self: *ErrorSet, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const Enum = struct {
        base: Type,

        pub fn destroy(self: *Enum, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const Union = struct {
        base: Type,

        pub fn destroy(self: *Union, module: *Module) void {
            module.a().destroy(self);
        }
    };
    pub const Namespace = struct {
        base: Type,

        pub fn destroy(self: *Namespace, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Block = struct {
        base: Type,

        pub fn destroy(self: *Block, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const BoundFn = struct {
        base: Type,

        pub fn destroy(self: *BoundFn, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const ArgTuple = struct {
        base: Type,

        pub fn destroy(self: *ArgTuple, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Opaque = struct {
        base: Type,

        pub fn destroy(self: *Opaque, module: *Module) void {
            module.a().destroy(self);
        }
    };

    pub const Promise = struct {
        base: Type,

        pub fn destroy(self: *Promise, module: *Module) void {
            module.a().destroy(self);
        }
    };
};
