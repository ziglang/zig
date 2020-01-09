const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_atomics = Feature{
    .name = "atomics",
    .llvm_name = "atomics",
    .description = "Enable Atomics",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_bulkMemory = Feature{
    .name = "bulkMemory",
    .llvm_name = "bulk-memory",
    .description = "Enable bulk memory operations",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_exceptionHandling = Feature{
    .name = "exceptionHandling",
    .llvm_name = "exception-handling",
    .description = "Enable Wasm exception handling",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_multivalue = Feature{
    .name = "multivalue",
    .llvm_name = "multivalue",
    .description = "Enable multivalue blocks, instructions, and functions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_mutableGlobals = Feature{
    .name = "mutableGlobals",
    .llvm_name = "mutable-globals",
    .description = "Enable mutable globals",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_nontrappingFptoint = Feature{
    .name = "nontrappingFptoint",
    .llvm_name = "nontrapping-fptoint",
    .description = "Enable non-trapping float-to-int conversion operators",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_simd128 = Feature{
    .name = "simd128",
    .llvm_name = "simd128",
    .description = "Enable 128-bit SIMD",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_signExt = Feature{
    .name = "signExt",
    .llvm_name = "sign-ext",
    .description = "Enable sign extension operators",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_tailCall = Feature{
    .name = "tailCall",
    .llvm_name = "tail-call",
    .description = "Enable tail call instructions",
    .dependencies = &[_]*const Feature {
    },
};

pub const feature_unimplementedSimd128 = Feature{
    .name = "unimplementedSimd128",
    .llvm_name = "unimplemented-simd128",
    .description = "Enable 128-bit SIMD not yet implemented in engines",
    .dependencies = &[_]*const Feature {
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
    .name = "bleedingEdge",
    .llvm_name = "bleeding-edge",
    .dependencies = &[_]*const Feature {
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
    .dependencies = &[_]*const Feature {
    },
};

pub const cpu_mvp = Cpu{
    .name = "mvp",
    .llvm_name = "mvp",
    .dependencies = &[_]*const Feature {
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_bleedingEdge,
    &cpu_generic,
    &cpu_mvp,
};
