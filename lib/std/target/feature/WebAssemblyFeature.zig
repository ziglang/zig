const FeatureInfo = @import("std").target.feature.FeatureInfo;

pub const WebAssemblyFeature = enum {
    Atomics,
    BulkMemory,
    ExceptionHandling,
    Multivalue,
    MutableGlobals,
    NontrappingFptoint,
    Simd128,
    SignExt,
    TailCall,
    UnimplementedSimd128,

    pub fn getInfo(self: @This()) FeatureInfo(@This()) {
        return feature_infos[@enumToInt(self)];
    }

    pub const feature_infos = [@memberCount(@This())]FeatureInfo(@This()) {
        FeatureInfo(@This()).create(.Atomics, "atomics", "Enable Atomics", "atomics"),
        FeatureInfo(@This()).create(.BulkMemory, "bulk-memory", "Enable bulk memory operations", "bulk-memory"),
        FeatureInfo(@This()).create(.ExceptionHandling, "exception-handling", "Enable Wasm exception handling", "exception-handling"),
        FeatureInfo(@This()).create(.Multivalue, "multivalue", "Enable multivalue blocks, instructions, and functions", "multivalue"),
        FeatureInfo(@This()).create(.MutableGlobals, "mutable-globals", "Enable mutable globals", "mutable-globals"),
        FeatureInfo(@This()).create(.NontrappingFptoint, "nontrapping-fptoint", "Enable non-trapping float-to-int conversion operators", "nontrapping-fptoint"),
        FeatureInfo(@This()).create(.Simd128, "simd128", "Enable 128-bit SIMD", "simd128"),
        FeatureInfo(@This()).create(.SignExt, "sign-ext", "Enable sign extension operators", "sign-ext"),
        FeatureInfo(@This()).create(.TailCall, "tail-call", "Enable tail call instructions", "tail-call"),
        FeatureInfo(@This()).createWithSubfeatures(.UnimplementedSimd128, "unimplemented-simd128", "Enable 128-bit SIMD not yet implemented in engines", "unimplemented-simd128", &[_]@This() {
            .Simd128,
        }),
    };
};
