const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_dfpPackedConversion = Feature{
    .name = "dfp-packed-conversion",
    .description = "Assume that the DFP packed-conversion facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_dfpZonedConversion = Feature{
    .name = "dfp-zoned-conversion",
    .description = "Assume that the DFP zoned-conversion facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_deflateConversion = Feature{
    .name = "deflate-conversion",
    .description = "Assume that the deflate-conversion facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_distinctOps = Feature{
    .name = "distinct-ops",
    .description = "Assume that the distinct-operands facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_enhancedDat2 = Feature{
    .name = "enhanced-dat-2",
    .description = "Assume that the enhanced-DAT facility 2 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_enhancedSort = Feature{
    .name = "enhanced-sort",
    .description = "Assume that the enhanced-sort facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_executionHint = Feature{
    .name = "execution-hint",
    .description = "Assume that the execution-hint facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fpExtension = Feature{
    .name = "fp-extension",
    .description = "Assume that the floating-point extension facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_fastSerialization = Feature{
    .name = "fast-serialization",
    .description = "Assume that the fast-serialization facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_guardedStorage = Feature{
    .name = "guarded-storage",
    .description = "Assume that the guarded-storage facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_highWord = Feature{
    .name = "high-word",
    .description = "Assume that the high-word facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_insertReferenceBitsMultiple = Feature{
    .name = "insert-reference-bits-multiple",
    .description = "Assume that the insert-reference-bits-multiple facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_interlockedAccess1 = Feature{
    .name = "interlocked-access1",
    .description = "Assume that interlocked-access facility 1 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_loadAndTrap = Feature{
    .name = "load-and-trap",
    .description = "Assume that the load-and-trap facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_loadAndZeroRightmostByte = Feature{
    .name = "load-and-zero-rightmost-byte",
    .description = "Assume that the load-and-zero-rightmost-byte facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_loadStoreOnCond = Feature{
    .name = "load-store-on-cond",
    .description = "Assume that the load/store-on-condition facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_loadStoreOnCond2 = Feature{
    .name = "load-store-on-cond-2",
    .description = "Assume that the load/store-on-condition facility 2 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_messageSecurityAssistExtension3 = Feature{
    .name = "message-security-assist-extension3",
    .description = "Assume that the message-security-assist extension facility 3 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_messageSecurityAssistExtension4 = Feature{
    .name = "message-security-assist-extension4",
    .description = "Assume that the message-security-assist extension facility 4 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_messageSecurityAssistExtension5 = Feature{
    .name = "message-security-assist-extension5",
    .description = "Assume that the message-security-assist extension facility 5 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_messageSecurityAssistExtension7 = Feature{
    .name = "message-security-assist-extension7",
    .description = "Assume that the message-security-assist extension facility 7 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_messageSecurityAssistExtension8 = Feature{
    .name = "message-security-assist-extension8",
    .description = "Assume that the message-security-assist extension facility 8 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_messageSecurityAssistExtension9 = Feature{
    .name = "message-security-assist-extension9",
    .description = "Assume that the message-security-assist extension facility 9 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_miscellaneousExtensions = Feature{
    .name = "miscellaneous-extensions",
    .description = "Assume that the miscellaneous-extensions facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_miscellaneousExtensions2 = Feature{
    .name = "miscellaneous-extensions-2",
    .description = "Assume that the miscellaneous-extensions facility 2 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_miscellaneousExtensions3 = Feature{
    .name = "miscellaneous-extensions-3",
    .description = "Assume that the miscellaneous-extensions facility 3 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_populationCount = Feature{
    .name = "population-count",
    .description = "Assume that the population-count facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_processorAssist = Feature{
    .name = "processor-assist",
    .description = "Assume that the processor-assist facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_resetReferenceBitsMultiple = Feature{
    .name = "reset-reference-bits-multiple",
    .description = "Assume that the reset-reference-bits-multiple facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_transactionalExecution = Feature{
    .name = "transactional-execution",
    .description = "Assume that the transactional-execution facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vector = Feature{
    .name = "vector",
    .description = "Assume that the vectory facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vectorEnhancements1 = Feature{
    .name = "vector-enhancements-1",
    .description = "Assume that the vector enhancements facility 1 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vectorEnhancements2 = Feature{
    .name = "vector-enhancements-2",
    .description = "Assume that the vector enhancements facility 2 is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vectorPackedDecimal = Feature{
    .name = "vector-packed-decimal",
    .description = "Assume that the vector packed decimal facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_vectorPackedDecimalEnhancement = Feature{
    .name = "vector-packed-decimal-enhancement",
    .description = "Assume that the vector packed decimal enhancement facility is installed",
    .subfeatures = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_dfpPackedConversion,
    &feature_dfpZonedConversion,
    &feature_deflateConversion,
    &feature_distinctOps,
    &feature_enhancedDat2,
    &feature_enhancedSort,
    &feature_executionHint,
    &feature_fpExtension,
    &feature_fastSerialization,
    &feature_guardedStorage,
    &feature_highWord,
    &feature_insertReferenceBitsMultiple,
    &feature_interlockedAccess1,
    &feature_loadAndTrap,
    &feature_loadAndZeroRightmostByte,
    &feature_loadStoreOnCond,
    &feature_loadStoreOnCond2,
    &feature_messageSecurityAssistExtension3,
    &feature_messageSecurityAssistExtension4,
    &feature_messageSecurityAssistExtension5,
    &feature_messageSecurityAssistExtension7,
    &feature_messageSecurityAssistExtension8,
    &feature_messageSecurityAssistExtension9,
    &feature_miscellaneousExtensions,
    &feature_miscellaneousExtensions2,
    &feature_miscellaneousExtensions3,
    &feature_populationCount,
    &feature_processorAssist,
    &feature_resetReferenceBitsMultiple,
    &feature_transactionalExecution,
    &feature_vector,
    &feature_vectorEnhancements1,
    &feature_vectorEnhancements2,
    &feature_vectorPackedDecimal,
    &feature_vectorPackedDecimalEnhancement,
};

pub const cpu_arch10 = Cpu{
    .name = "arch10",
    .llvm_name = "arch10",
    .subfeatures = &[_]*const Feature {
        &feature_dfpZonedConversion,
        &feature_distinctOps,
        &feature_enhancedDat2,
        &feature_executionHint,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_highWord,
        &feature_interlockedAccess1,
        &feature_loadAndTrap,
        &feature_loadStoreOnCond,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_miscellaneousExtensions,
        &feature_populationCount,
        &feature_processorAssist,
        &feature_resetReferenceBitsMultiple,
        &feature_transactionalExecution,
    },
};

pub const cpu_arch11 = Cpu{
    .name = "arch11",
    .llvm_name = "arch11",
    .subfeatures = &[_]*const Feature {
        &feature_dfpPackedConversion,
        &feature_dfpZonedConversion,
        &feature_distinctOps,
        &feature_enhancedDat2,
        &feature_executionHint,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_highWord,
        &feature_interlockedAccess1,
        &feature_loadAndTrap,
        &feature_loadAndZeroRightmostByte,
        &feature_loadStoreOnCond,
        &feature_loadStoreOnCond2,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_messageSecurityAssistExtension5,
        &feature_miscellaneousExtensions,
        &feature_populationCount,
        &feature_processorAssist,
        &feature_resetReferenceBitsMultiple,
        &feature_transactionalExecution,
        &feature_vector,
    },
};

pub const cpu_arch12 = Cpu{
    .name = "arch12",
    .llvm_name = "arch12",
    .subfeatures = &[_]*const Feature {
        &feature_dfpPackedConversion,
        &feature_dfpZonedConversion,
        &feature_distinctOps,
        &feature_enhancedDat2,
        &feature_executionHint,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_guardedStorage,
        &feature_highWord,
        &feature_insertReferenceBitsMultiple,
        &feature_interlockedAccess1,
        &feature_loadAndTrap,
        &feature_loadAndZeroRightmostByte,
        &feature_loadStoreOnCond,
        &feature_loadStoreOnCond2,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_messageSecurityAssistExtension5,
        &feature_messageSecurityAssistExtension7,
        &feature_messageSecurityAssistExtension8,
        &feature_miscellaneousExtensions,
        &feature_miscellaneousExtensions2,
        &feature_populationCount,
        &feature_processorAssist,
        &feature_resetReferenceBitsMultiple,
        &feature_transactionalExecution,
        &feature_vector,
        &feature_vectorEnhancements1,
        &feature_vectorPackedDecimal,
    },
};

pub const cpu_arch13 = Cpu{
    .name = "arch13",
    .llvm_name = "arch13",
    .subfeatures = &[_]*const Feature {
        &feature_dfpPackedConversion,
        &feature_dfpZonedConversion,
        &feature_deflateConversion,
        &feature_distinctOps,
        &feature_enhancedDat2,
        &feature_enhancedSort,
        &feature_executionHint,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_guardedStorage,
        &feature_highWord,
        &feature_insertReferenceBitsMultiple,
        &feature_interlockedAccess1,
        &feature_loadAndTrap,
        &feature_loadAndZeroRightmostByte,
        &feature_loadStoreOnCond,
        &feature_loadStoreOnCond2,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_messageSecurityAssistExtension5,
        &feature_messageSecurityAssistExtension7,
        &feature_messageSecurityAssistExtension8,
        &feature_messageSecurityAssistExtension9,
        &feature_miscellaneousExtensions,
        &feature_miscellaneousExtensions2,
        &feature_miscellaneousExtensions3,
        &feature_populationCount,
        &feature_processorAssist,
        &feature_resetReferenceBitsMultiple,
        &feature_transactionalExecution,
        &feature_vector,
        &feature_vectorEnhancements1,
        &feature_vectorEnhancements2,
        &feature_vectorPackedDecimal,
        &feature_vectorPackedDecimalEnhancement,
    },
};

pub const cpu_arch8 = Cpu{
    .name = "arch8",
    .llvm_name = "arch8",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_arch9 = Cpu{
    .name = "arch9",
    .llvm_name = "arch9",
    .subfeatures = &[_]*const Feature {
        &feature_distinctOps,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_highWord,
        &feature_interlockedAccess1,
        &feature_loadStoreOnCond,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_populationCount,
        &feature_resetReferenceBitsMultiple,
    },
};

pub const cpu_generic = Cpu{
    .name = "generic",
    .llvm_name = "generic",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_z10 = Cpu{
    .name = "z10",
    .llvm_name = "z10",
    .subfeatures = &[_]*const Feature {
    },
};

pub const cpu_z13 = Cpu{
    .name = "z13",
    .llvm_name = "z13",
    .subfeatures = &[_]*const Feature {
        &feature_dfpPackedConversion,
        &feature_dfpZonedConversion,
        &feature_distinctOps,
        &feature_enhancedDat2,
        &feature_executionHint,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_highWord,
        &feature_interlockedAccess1,
        &feature_loadAndTrap,
        &feature_loadAndZeroRightmostByte,
        &feature_loadStoreOnCond,
        &feature_loadStoreOnCond2,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_messageSecurityAssistExtension5,
        &feature_miscellaneousExtensions,
        &feature_populationCount,
        &feature_processorAssist,
        &feature_resetReferenceBitsMultiple,
        &feature_transactionalExecution,
        &feature_vector,
    },
};

pub const cpu_z14 = Cpu{
    .name = "z14",
    .llvm_name = "z14",
    .subfeatures = &[_]*const Feature {
        &feature_dfpPackedConversion,
        &feature_dfpZonedConversion,
        &feature_distinctOps,
        &feature_enhancedDat2,
        &feature_executionHint,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_guardedStorage,
        &feature_highWord,
        &feature_insertReferenceBitsMultiple,
        &feature_interlockedAccess1,
        &feature_loadAndTrap,
        &feature_loadAndZeroRightmostByte,
        &feature_loadStoreOnCond,
        &feature_loadStoreOnCond2,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_messageSecurityAssistExtension5,
        &feature_messageSecurityAssistExtension7,
        &feature_messageSecurityAssistExtension8,
        &feature_miscellaneousExtensions,
        &feature_miscellaneousExtensions2,
        &feature_populationCount,
        &feature_processorAssist,
        &feature_resetReferenceBitsMultiple,
        &feature_transactionalExecution,
        &feature_vector,
        &feature_vectorEnhancements1,
        &feature_vectorPackedDecimal,
    },
};

pub const cpu_z15 = Cpu{
    .name = "z15",
    .llvm_name = "z15",
    .subfeatures = &[_]*const Feature {
        &feature_dfpPackedConversion,
        &feature_dfpZonedConversion,
        &feature_deflateConversion,
        &feature_distinctOps,
        &feature_enhancedDat2,
        &feature_enhancedSort,
        &feature_executionHint,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_guardedStorage,
        &feature_highWord,
        &feature_insertReferenceBitsMultiple,
        &feature_interlockedAccess1,
        &feature_loadAndTrap,
        &feature_loadAndZeroRightmostByte,
        &feature_loadStoreOnCond,
        &feature_loadStoreOnCond2,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_messageSecurityAssistExtension5,
        &feature_messageSecurityAssistExtension7,
        &feature_messageSecurityAssistExtension8,
        &feature_messageSecurityAssistExtension9,
        &feature_miscellaneousExtensions,
        &feature_miscellaneousExtensions2,
        &feature_miscellaneousExtensions3,
        &feature_populationCount,
        &feature_processorAssist,
        &feature_resetReferenceBitsMultiple,
        &feature_transactionalExecution,
        &feature_vector,
        &feature_vectorEnhancements1,
        &feature_vectorEnhancements2,
        &feature_vectorPackedDecimal,
        &feature_vectorPackedDecimalEnhancement,
    },
};

pub const cpu_z196 = Cpu{
    .name = "z196",
    .llvm_name = "z196",
    .subfeatures = &[_]*const Feature {
        &feature_distinctOps,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_highWord,
        &feature_interlockedAccess1,
        &feature_loadStoreOnCond,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_populationCount,
        &feature_resetReferenceBitsMultiple,
    },
};

pub const cpu_zEC12 = Cpu{
    .name = "zEC12",
    .llvm_name = "zEC12",
    .subfeatures = &[_]*const Feature {
        &feature_dfpZonedConversion,
        &feature_distinctOps,
        &feature_enhancedDat2,
        &feature_executionHint,
        &feature_fpExtension,
        &feature_fastSerialization,
        &feature_highWord,
        &feature_interlockedAccess1,
        &feature_loadAndTrap,
        &feature_loadStoreOnCond,
        &feature_messageSecurityAssistExtension3,
        &feature_messageSecurityAssistExtension4,
        &feature_miscellaneousExtensions,
        &feature_populationCount,
        &feature_processorAssist,
        &feature_resetReferenceBitsMultiple,
        &feature_transactionalExecution,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_arch10,
    &cpu_arch11,
    &cpu_arch12,
    &cpu_arch13,
    &cpu_arch8,
    &cpu_arch9,
    &cpu_generic,
    &cpu_z10,
    &cpu_z13,
    &cpu_z14,
    &cpu_z15,
    &cpu_z196,
    &cpu_zEC12,
};
