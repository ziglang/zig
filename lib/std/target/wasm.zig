const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_atomics = Feature{
    .name = "atomics",
    .description = "Enable Atomics",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_bulkMemory = Feature{
    .name = "bulk-memory",
    .description = "Enable bulk memory operations",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_exceptionHandling = Feature{
    .name = "exception-handling",
    .description = "Enable Wasm exception handling",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_multivalue = Feature{
    .name = "multivalue",
    .description = "Enable multivalue blocks, instructions, and functions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_mutableGlobals = Feature{
    .name = "mutable-globals",
    .description = "Enable mutable globals",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_nontrappingFptoint = Feature{
    .name = "nontrapping-fptoint",
    .description = "Enable non-trapping float-to-int conversion operators",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_simd128 = Feature{
    .name = "simd128",
    .description = "Enable 128-bit SIMD",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_signExt = Feature{
    .name = "sign-ext",
    .description = "Enable sign extension operators",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_tailCall = Feature{
    .name = "tail-call",
    .description = "Enable tail call instructions",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_unimplementedSimd128 = Feature{
    .name = "unimplemented-simd128",
    .description = "Enable 128-bit SIMD not yet implemented in engines",
    .subfeatures = &[_]*const Feature {
        &feature_simd128,
    },
};

pub const features = &[_]*const Feature {
    &feature_atomics,
    &feature_bulkMemory,
    &feature_exceptionHandling,
    &feature_multivalue,
    &feature_mutableGlobals,
    &feature_nontrappingFptoint,
    &feature_simd128,
    &feature_signExt,
    &feature_tailCall,
    &feature_unimplementedSimd128,
};

pub const cpu_bleedingEdge = Cpu{
    .name = "bleeding-edge",
    .llvm_name = "bleeding-edge",
    .subfeatures = &[_]*const Feature {
        &feature_atomics,
        &feature_mutableGlobals,
        &feature_nontrappingFptoint,
        &feature_simd128,
        &feature_signExt,
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_mvp = Cpu{
    .name = "mvp",
    .llvm_name = "mvp",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_bleedingEdge,
    &cpu_generic,
    &cpu_mvp,
};
