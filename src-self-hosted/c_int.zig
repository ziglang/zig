pub const CInt = struct {
    id: Id,
    zig_name: []const u8,
    c_name: []const u8,
    is_signed: bool,

    pub const Id = enum {
        Short,
        UShort,
        Int,
        UInt,
        Long,
        ULong,
        LongLong,
        ULongLong,
    };

    pub const list = []CInt{
        CInt{
            .id = Id.Short,
            .zig_name = "c_short",
            .c_name = "short",
            .is_signed = true,
        },
        CInt{
            .id = Id.UShort,
            .zig_name = "c_ushort",
            .c_name = "unsigned short",
            .is_signed = false,
        },
        CInt{
            .id = Id.Int,
            .zig_name = "c_int",
            .c_name = "int",
            .is_signed = true,
        },
        CInt{
            .id = Id.UInt,
            .zig_name = "c_uint",
            .c_name = "unsigned int",
            .is_signed = false,
        },
        CInt{
            .id = Id.Long,
            .zig_name = "c_long",
            .c_name = "long",
            .is_signed = true,
        },
        CInt{
            .id = Id.ULong,
            .zig_name = "c_ulong",
            .c_name = "unsigned long",
            .is_signed = false,
        },
        CInt{
            .id = Id.LongLong,
            .zig_name = "c_longlong",
            .c_name = "long long",
            .is_signed = true,
        },
        CInt{
            .id = Id.ULongLong,
            .zig_name = "c_ulonglong",
            .c_name = "unsigned long long",
            .is_signed = false,
        },
    };
};
