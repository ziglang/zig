const Feature = @import("std").target.Feature;
const Cpu = @import("std").target.Cpu;

pub const feature_ptx32 = Feature{
    .name = "ptx32",
    .description = "Use PTX version 3.2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx40 = Feature{
    .name = "ptx40",
    .description = "Use PTX version 4.0",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx41 = Feature{
    .name = "ptx41",
    .description = "Use PTX version 4.1",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx42 = Feature{
    .name = "ptx42",
    .description = "Use PTX version 4.2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx43 = Feature{
    .name = "ptx43",
    .description = "Use PTX version 4.3",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx50 = Feature{
    .name = "ptx50",
    .description = "Use PTX version 5.0",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx60 = Feature{
    .name = "ptx60",
    .description = "Use PTX version 6.0",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx61 = Feature{
    .name = "ptx61",
    .description = "Use PTX version 6.1",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx63 = Feature{
    .name = "ptx63",
    .description = "Use PTX version 6.3",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_ptx64 = Feature{
    .name = "ptx64",
    .description = "Use PTX version 6.4",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_20 = Feature{
    .name = "sm_20",
    .description = "Target SM 2.0",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_21 = Feature{
    .name = "sm_21",
    .description = "Target SM 2.1",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_30 = Feature{
    .name = "sm_30",
    .description = "Target SM 3.0",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_32 = Feature{
    .name = "sm_32",
    .description = "Target SM 3.2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_35 = Feature{
    .name = "sm_35",
    .description = "Target SM 3.5",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_37 = Feature{
    .name = "sm_37",
    .description = "Target SM 3.7",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_50 = Feature{
    .name = "sm_50",
    .description = "Target SM 5.0",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_52 = Feature{
    .name = "sm_52",
    .description = "Target SM 5.2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_53 = Feature{
    .name = "sm_53",
    .description = "Target SM 5.3",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_60 = Feature{
    .name = "sm_60",
    .description = "Target SM 6.0",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_61 = Feature{
    .name = "sm_61",
    .description = "Target SM 6.1",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_62 = Feature{
    .name = "sm_62",
    .description = "Target SM 6.2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_70 = Feature{
    .name = "sm_70",
    .description = "Target SM 7.0",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_72 = Feature{
    .name = "sm_72",
    .description = "Target SM 7.2",
    .subfeatures = &[_]*const Feature {
    },
};

pub const feature_sm_75 = Feature{
    .name = "sm_75",
    .description = "Target SM 7.5",
    .subfeatures = &[_]*const Feature {
    },
};

pub const features = &[_]*const Feature {
    &feature_ptx32,
    &feature_ptx40,
    &feature_ptx41,
    &feature_ptx42,
    &feature_ptx43,
    &feature_ptx50,
    &feature_ptx60,
    &feature_ptx61,
    &feature_ptx63,
    &feature_ptx64,
    &feature_sm_20,
    &feature_sm_21,
    &feature_sm_30,
    &feature_sm_32,
    &feature_sm_35,
    &feature_sm_37,
    &feature_sm_50,
    &feature_sm_52,
    &feature_sm_53,
    &feature_sm_60,
    &feature_sm_61,
    &feature_sm_62,
    &feature_sm_70,
    &feature_sm_72,
    &feature_sm_75,
};

pub const cpu_sm_20 = Cpu{
    .name = "sm_20",
    .llvm_name = "sm_20",
    .subfeatures = &[_]*const Feature {
        &feature_sm_20,
    },
};

pub const cpu_sm_21 = Cpu{
    .name = "sm_21",
    .llvm_name = "sm_21",
    .subfeatures = &[_]*const Feature {
        &feature_sm_21,
    },
};

pub const cpu_sm_30 = Cpu{
    .name = "sm_30",
    .llvm_name = "sm_30",
    .subfeatures = &[_]*const Feature {
        &feature_sm_30,
    },
};

pub const cpu_sm_32 = Cpu{
    .name = "sm_32",
    .llvm_name = "sm_32",
    .subfeatures = &[_]*const Feature {
        &feature_ptx40,
        &feature_sm_32,
    },
};

pub const cpu_sm_35 = Cpu{
    .name = "sm_35",
    .llvm_name = "sm_35",
    .subfeatures = &[_]*const Feature {
        &feature_sm_35,
    },
};

pub const cpu_sm_37 = Cpu{
    .name = "sm_37",
    .llvm_name = "sm_37",
    .subfeatures = &[_]*const Feature {
        &feature_ptx41,
        &feature_sm_37,
    },
};

pub const cpu_sm_50 = Cpu{
    .name = "sm_50",
    .llvm_name = "sm_50",
    .subfeatures = &[_]*const Feature {
        &feature_ptx40,
        &feature_sm_50,
    },
};

pub const cpu_sm_52 = Cpu{
    .name = "sm_52",
    .llvm_name = "sm_52",
    .subfeatures = &[_]*const Feature {
        &feature_ptx41,
        &feature_sm_52,
    },
};

pub const cpu_sm_53 = Cpu{
    .name = "sm_53",
    .llvm_name = "sm_53",
    .subfeatures = &[_]*const Feature {
        &feature_ptx42,
        &feature_sm_53,
    },
};

pub const cpu_sm_60 = Cpu{
    .name = "sm_60",
    .llvm_name = "sm_60",
    .subfeatures = &[_]*const Feature {
        &feature_ptx50,
        &feature_sm_60,
    },
};

pub const cpu_sm_61 = Cpu{
    .name = "sm_61",
    .llvm_name = "sm_61",
    .subfeatures = &[_]*const Feature {
        &feature_ptx50,
        &feature_sm_61,
    },
};

pub const cpu_sm_62 = Cpu{
    .name = "sm_62",
    .llvm_name = "sm_62",
    .subfeatures = &[_]*const Feature {
        &feature_ptx50,
        &feature_sm_62,
    },
};

pub const cpu_sm_70 = Cpu{
    .name = "sm_70",
    .llvm_name = "sm_70",
    .subfeatures = &[_]*const Feature {
        &feature_ptx60,
        &feature_sm_70,
    },
};

pub const cpu_sm_72 = Cpu{
    .name = "sm_72",
    .llvm_name = "sm_72",
    .subfeatures = &[_]*const Feature {
        &feature_ptx61,
        &feature_sm_72,
    },
};

pub const cpu_sm_75 = Cpu{
    .name = "sm_75",
    .llvm_name = "sm_75",
    .subfeatures = &[_]*const Feature {
        &feature_ptx63,
        &feature_sm_75,
    },
};

pub const cpus = &[_]*const Cpu {
    &cpu_sm_20,
    &cpu_sm_21,
    &cpu_sm_30,
    &cpu_sm_32,
    &cpu_sm_35,
    &cpu_sm_37,
    &cpu_sm_50,
    &cpu_sm_52,
    &cpu_sm_53,
    &cpu_sm_60,
    &cpu_sm_61,
    &cpu_sm_62,
    &cpu_sm_70,
    &cpu_sm_72,
    &cpu_sm_75,
};
