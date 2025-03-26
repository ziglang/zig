/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */


/*
 * The point of this file is to contain all the LLVM C++ API interaction so that:
 * 1. The compile time of other files is kept under control.
 * 2. Provide a C interface to the LLVM functions we need for self-hosting purposes.
 * 3. Prevent C++ from infecting the rest of the project.
 */

#include "zig_llvm.h"

#if __GNUC__ >= 9
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Winit-list-lifetime"
#endif

#include <llvm/Analysis/AliasAnalysis.h>
#include <llvm/Analysis/TargetLibraryInfo.h>
#include <llvm/Analysis/TargetTransformInfo.h>
#include <llvm/Bitcode/BitcodeWriter.h>
#include <llvm/IR/DiagnosticInfo.h>
#include <llvm/IR/InlineAsm.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/OptBisect.h>
#include <llvm/IR/PassManager.h>
#include <llvm/IR/Verifier.h>
#include <llvm/InitializePasses.h>
#include <llvm/MC/TargetRegistry.h>
#include <llvm/Passes/OptimizationLevel.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Passes/StandardInstrumentations.h>
#include <llvm/Object/Archive.h>
#include <llvm/Object/ArchiveWriter.h>
#include <llvm/Object/COFF.h>
#include <llvm/Object/COFFImportFile.h>
#include <llvm/Object/COFFModuleDefinition.h>
#include <llvm/PassRegistry.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/Process.h>
#include <llvm/Support/TimeProfiler.h>
#include <llvm/Support/Timer.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Target/TargetOptions.h>
#include <llvm/Target/CodeGenCWrappers.h>
#include <llvm/Transforms/IPO.h>
#include <llvm/Transforms/IPO/AlwaysInliner.h>
#include <llvm/Transforms/Instrumentation/ThreadSanitizer.h>
#include <llvm/Transforms/Instrumentation/SanitizerCoverage.h>
#include <llvm/Transforms/Scalar.h>
#include <llvm/Transforms/Utils.h>
#include <llvm/Transforms/Utils/AddDiscriminators.h>
#include <llvm/Transforms/Utils/CanonicalizeAliases.h>
#include <llvm/Transforms/Utils/NameAnonGlobals.h>

#include <lld/Common/Driver.h>

#if __GNUC__ >= 9
#pragma GCC diagnostic pop
#endif

#include <new>

#include <stdlib.h>

using namespace llvm;

#ifndef NDEBUG
static const bool assertions_on = true;
#else
static const bool assertions_on = false;
#endif

LLVMTargetMachineRef ZigLLVMCreateTargetMachine(LLVMTargetRef T, const char *Triple,
    const char *CPU, const char *Features, LLVMCodeGenOptLevel Level, LLVMRelocMode Reloc,
    LLVMCodeModel CodeModel, bool function_sections, bool data_sections, ZigLLVMFloatABI float_abi,
    const char *abi_name)
{
    std::optional<Reloc::Model> RM;
    switch (Reloc){
        case LLVMRelocStatic:
            RM = Reloc::Static;
            break;
        case LLVMRelocPIC:
            RM = Reloc::PIC_;
            break;
        case LLVMRelocDynamicNoPic:
            RM = Reloc::DynamicNoPIC;
            break;
        case LLVMRelocROPI:
            RM = Reloc::ROPI;
            break;
        case LLVMRelocRWPI:
            RM = Reloc::RWPI;
            break;
        case LLVMRelocROPI_RWPI:
            RM = Reloc::ROPI_RWPI;
            break;
        default:
            break;
    }

    bool JIT;
    std::optional<CodeModel::Model> CM = unwrap(CodeModel, JIT);

    CodeGenOptLevel OL;
    switch (Level) {
        case LLVMCodeGenLevelNone:
            OL = CodeGenOptLevel::None;
            break;
        case LLVMCodeGenLevelLess:
            OL = CodeGenOptLevel::Less;
            break;
        case LLVMCodeGenLevelAggressive:
            OL = CodeGenOptLevel::Aggressive;
            break;
        default:
            OL = CodeGenOptLevel::Default;
            break;
    }

    TargetOptions opt;

    opt.UseInitArray = true;
    opt.FunctionSections = function_sections;
    opt.DataSections = data_sections;
    switch (float_abi) {
        case ZigLLVMFloatABI_Default:
            opt.FloatABIType = FloatABI::Default;
            break;
        case ZigLLVMFloatABI_Soft:
            opt.FloatABIType = FloatABI::Soft;
            break;
        case ZigLLVMFloatABI_Hard:
            opt.FloatABIType = FloatABI::Hard;
            break;
    }

    if (abi_name != nullptr) {
        opt.MCOptions.ABIName = abi_name;
    }

    TargetMachine *TM = reinterpret_cast<Target*>(T)->createTargetMachine(Triple, CPU, Features, opt, RM, CM,
            OL, JIT);
    return reinterpret_cast<LLVMTargetMachineRef>(TM);
}

namespace {
// LLVM's time profiler can provide a hierarchy view of the time spent
// in each component. It generates JSON report in Chrome's "Trace Event"
// format. So the report can be easily visualized by the Chrome browser.
struct TimeTracerRAII {
  // Granularity in ms
  unsigned TimeTraceGranularity;
  StringRef TimeTraceFile, OutputFilename;
  bool EnableTimeTrace;

  TimeTracerRAII(StringRef ProgramName, StringRef OF)
    : TimeTraceGranularity(500U),
      TimeTraceFile(std::getenv("ZIG_LLVM_TIME_TRACE_FILE")),
      OutputFilename(OF),
      EnableTimeTrace(!TimeTraceFile.empty()) {
    if (EnableTimeTrace) {
      if (const char *G = std::getenv("ZIG_LLVM_TIME_TRACE_GRANULARITY"))
        TimeTraceGranularity = (unsigned)std::atoi(G);

      llvm::timeTraceProfilerInitialize(TimeTraceGranularity, ProgramName);
    }
  }

  ~TimeTracerRAII() {
    if (EnableTimeTrace) {
      if (auto E = llvm::timeTraceProfilerWrite(TimeTraceFile, OutputFilename)) {
        handleAllErrors(std::move(E), [&](const StringError &SE) {
          errs() << SE.getMessage() << "\n";
        });
        return;
      }
      timeTraceProfilerCleanup();
    }
  }
};
} // end anonymous namespace

static SanitizerCoverageOptions getSanCovOptions(ZigLLVMCoverageOptions z) {
    SanitizerCoverageOptions o;
    o.CoverageType = (SanitizerCoverageOptions::Type)z.CoverageType;
    o.IndirectCalls = z.IndirectCalls;
    o.TraceBB = z.TraceBB;
    o.TraceCmp = z.TraceCmp;
    o.TraceDiv = z.TraceDiv;
    o.TraceGep = z.TraceGep;
    o.Use8bitCounters = z.Use8bitCounters;
    o.TracePC = z.TracePC;
    o.TracePCGuard = z.TracePCGuard;
    o.Inline8bitCounters = z.Inline8bitCounters;
    o.InlineBoolFlag = z.InlineBoolFlag;
    o.PCTable = z.PCTable;
    o.NoPrune = z.NoPrune;
    o.StackDepth = z.StackDepth;
    o.TraceLoads = z.TraceLoads;
    o.TraceStores = z.TraceStores;
    o.CollectControlFlow = z.CollectControlFlow;
    return o;
}

ZIG_EXTERN_C bool ZigLLVMTargetMachineEmitToFile(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref,
    char **error_message, const ZigLLVMEmitOptions *options)
{
    TimePassesIsEnabled = options->time_report;

    raw_fd_ostream *dest_asm_ptr = nullptr;
    raw_fd_ostream *dest_bin_ptr = nullptr;
    raw_fd_ostream *dest_bitcode_ptr = nullptr;

    if (options->asm_filename) {
        std::error_code EC;
        dest_asm_ptr = new(std::nothrow) raw_fd_ostream(options->asm_filename, EC, sys::fs::OF_None);
        if (EC) {
            *error_message = strdup((const char *)StringRef(EC.message()).bytes_begin());
            return true;
        }
    }
    if (options->bin_filename) {
        std::error_code EC;
        dest_bin_ptr = new(std::nothrow) raw_fd_ostream(options->bin_filename, EC, sys::fs::OF_None);
        if (EC) {
            *error_message = strdup((const char *)StringRef(EC.message()).bytes_begin());
            return true;
        }
    }
    if (options->bitcode_filename) {
        std::error_code EC;
        dest_bitcode_ptr = new(std::nothrow) raw_fd_ostream(options->bitcode_filename, EC, sys::fs::OF_None);
        if (EC) {
            *error_message = strdup((const char *)StringRef(EC.message()).bytes_begin());
            return true;
        }
    }

    std::unique_ptr<raw_fd_ostream> dest_asm(dest_asm_ptr),
                                    dest_bin(dest_bin_ptr),
                                    dest_bitcode(dest_bitcode_ptr);


    auto PID = sys::Process::getProcessId();
    std::string ProcName = "zig-";
    ProcName += std::to_string(PID);
    TimeTracerRAII TimeTracer(ProcName,
                              options->bin_filename? options->bin_filename : options->asm_filename);

    TargetMachine &target_machine = *reinterpret_cast<TargetMachine*>(targ_machine_ref);

    Module &llvm_module = *unwrap(module_ref);

    // Pipeline configurations
    PipelineTuningOptions pipeline_opts;
    pipeline_opts.LoopUnrolling = !options->is_debug;
    pipeline_opts.SLPVectorization = !options->is_debug;
    pipeline_opts.LoopVectorization = !options->is_debug;
    pipeline_opts.LoopInterleaving = !options->is_debug;
    pipeline_opts.MergeFunctions = !options->is_debug;

    // Instrumentations
    PassInstrumentationCallbacks instr_callbacks;
    StandardInstrumentations std_instrumentations(llvm_module.getContext(), false);
    std_instrumentations.registerCallbacks(instr_callbacks);

    std::optional<PGOOptions> opt_pgo_options = {};
    PassBuilder pass_builder(&target_machine, pipeline_opts,
                             opt_pgo_options, &instr_callbacks);

    LoopAnalysisManager loop_am;
    FunctionAnalysisManager function_am;
    CGSCCAnalysisManager cgscc_am;
    ModuleAnalysisManager module_am;

    // Register the AA manager first so that our version is the one used
    function_am.registerPass([&] {
      return pass_builder.buildDefaultAAPipeline();
    });

    Triple target_triple(llvm_module.getTargetTriple());
    auto tlii = std::make_unique<TargetLibraryInfoImpl>(target_triple);
    function_am.registerPass([&] { return TargetLibraryAnalysis(*tlii); });

    // Initialize the AnalysisManagers
    pass_builder.registerModuleAnalyses(module_am);
    pass_builder.registerCGSCCAnalyses(cgscc_am);
    pass_builder.registerFunctionAnalyses(function_am);
    pass_builder.registerLoopAnalyses(loop_am);
    pass_builder.crossRegisterProxies(loop_am, function_am, cgscc_am, module_am);

    pass_builder.registerPipelineStartEPCallback([&](ModulePassManager &module_pm, OptimizationLevel OL) {
        // Verify the input
        if (assertions_on) {
            module_pm.addPass(VerifierPass());
        }

        if (!options->is_debug) {
            module_pm.addPass(createModuleToFunctionPassAdaptor(AddDiscriminatorsPass()));
        }
    });

    const bool early_san = options->is_debug;

    pass_builder.registerOptimizerEarlyEPCallback([&](ModulePassManager &module_pm, OptimizationLevel OL) {
        if (early_san) {
            // Code coverage instrumentation.
            if (options->sancov) {
                module_pm.addPass(SanitizerCoveragePass(getSanCovOptions(options->coverage)));
            }

            // Thread sanitizer
            if (options->tsan) {
                module_pm.addPass(ModuleThreadSanitizerPass());
                module_pm.addPass(createModuleToFunctionPassAdaptor(ThreadSanitizerPass()));
            }
        }
    });

    pass_builder.registerOptimizerLastEPCallback([&](ModulePassManager &module_pm, OptimizationLevel level) {
        if (!early_san) {
            // Code coverage instrumentation.
            if (options->sancov) {
                module_pm.addPass(SanitizerCoveragePass(getSanCovOptions(options->coverage)));
            }

            // Thread sanitizer
            if (options->tsan) {
                module_pm.addPass(ModuleThreadSanitizerPass());
                module_pm.addPass(createModuleToFunctionPassAdaptor(ThreadSanitizerPass()));
            }
        }

        // Verify the output
        if (assertions_on) {
            module_pm.addPass(VerifierPass());
        }
    });

    ModulePassManager module_pm;
    OptimizationLevel opt_level;
    // Setting up the optimization level
    if (options->is_debug)
      opt_level = OptimizationLevel::O0;
    else if (options->is_small)
      opt_level = OptimizationLevel::Oz;
    else
      opt_level = OptimizationLevel::O3;

    // Initialize the PassManager
    if (opt_level == OptimizationLevel::O0) {
      module_pm = pass_builder.buildO0DefaultPipeline(opt_level, options->lto);
    } else if (options->lto) {
      module_pm = pass_builder.buildLTOPreLinkDefaultPipeline(opt_level);
    } else {
      module_pm = pass_builder.buildPerModuleDefaultPipeline(opt_level);
    }

    // Unfortunately we don't have new PM for code generation
    legacy::PassManager codegen_pm;
    codegen_pm.add(
      createTargetTransformInfoWrapperPass(target_machine.getTargetIRAnalysis()));

    if (dest_bin && !options->lto) {
        if (target_machine.addPassesToEmitFile(codegen_pm, *dest_bin, nullptr, CodeGenFileType::ObjectFile)) {
            *error_message = strdup("TargetMachine can't emit an object file");
            return true;
        }
    }
    if (dest_asm) {
        if (target_machine.addPassesToEmitFile(codegen_pm, *dest_asm, nullptr, CodeGenFileType::AssemblyFile)) {
            *error_message = strdup("TargetMachine can't emit an assembly file");
            return true;
        }
    }

    if (options->allow_fast_isel) {
        target_machine.setO0WantsFastISel(true);
    } else {
        target_machine.setFastISel(false);
    }

    // Optimization phase
    module_pm.run(llvm_module, module_am);

    // Code generation phase
    codegen_pm.run(llvm_module);

    if (options->llvm_ir_filename) {
        if (LLVMPrintModuleToFile(module_ref, options->llvm_ir_filename, error_message)) {
            return true;
        }
    }

    if (dest_bin && options->lto) {
        WriteBitcodeToFile(llvm_module, *dest_bin);
    }
    if (dest_bitcode) {
        WriteBitcodeToFile(llvm_module, *dest_bitcode);
    }

    if (options->time_report) {
        TimerGroup::printAll(errs());
    }

    return false;
}

void ZigLLVMSetOptBisectLimit(LLVMContextRef context_ref, int limit) {
    static OptBisect opt_bisect;
    opt_bisect.setLimit(limit);
    unwrap(context_ref)->setOptPassGate(opt_bisect);
}

struct ZigDiagnosticHandler : public DiagnosticHandler {
    bool BrokenDebugInfo;
    ZigDiagnosticHandler() : BrokenDebugInfo(false) {}
    bool handleDiagnostics(const DiagnosticInfo &DI) override {
        // This dyn_cast should be casting to DiagnosticInfoIgnoringInvalidDebugMetadata
        // but DiagnosticInfoIgnoringInvalidDebugMetadata is treated as DiagnosticInfoDebugMetadataVersion
        // because of a bug in LLVM (see https://github.com/ziglang/zig/issues/19161).
        // After this is fixed add an additional check for DiagnosticInfoIgnoringInvalidDebugMetadata
        // but don't remove the current one as both indicate that debug info is broken.
        if (auto *Remark = dyn_cast<DiagnosticInfoDebugMetadataVersion>(&DI)) {
            BrokenDebugInfo = true;
        }
        return false;
    }
};

void ZigLLVMEnableBrokenDebugInfoCheck(LLVMContextRef context_ref) {
    unwrap(context_ref)->setDiagnosticHandler(std::make_unique<ZigDiagnosticHandler>());
}

bool ZigLLVMGetBrokenDebugInfo(LLVMContextRef context_ref) {
    return ((const ZigDiagnosticHandler*)
        unwrap(context_ref)->getDiagHandlerPtr())->BrokenDebugInfo;
}

void ZigLLVMParseCommandLineOptions(size_t argc, const char *const *argv) {
    cl::ParseCommandLineOptions(argc, argv);
}

bool ZigLLVMWriteImportLibrary(const char *def_path, unsigned int coff_machine,
    const char *output_lib_path, bool kill_at)
{
    COFF::MachineTypes machine = static_cast<COFF::MachineTypes>(coff_machine);

    auto bufOrErr = MemoryBuffer::getFile(def_path);
    if (!bufOrErr) {
        return false;
    }

    MemoryBuffer& buf = *bufOrErr.get();
    Expected<object::COFFModuleDefinition> def =
        object::parseCOFFModuleDefinition(buf, machine, /* MingwDef */ true);

    if (!def) {
        return true;
    }

    // The exports-juggling code below is ripped from LLVM's DlltoolDriver.cpp

    // If ExtName is set (if the "ExtName = Name" syntax was used), overwrite
    // Name with ExtName and clear ExtName. When only creating an import
    // library and not linking, the internal name is irrelevant. This avoids
    // cases where writeImportLibrary tries to transplant decoration from
    // symbol decoration onto ExtName.
    for (object::COFFShortExport& E : def->Exports) {
        if (!E.ExtName.empty()) {
            E.Name = E.ExtName;
            E.ExtName.clear();
        }
    }

    if (machine == COFF::IMAGE_FILE_MACHINE_I386 && kill_at) {
        for (object::COFFShortExport& E : def->Exports) {
            if (!E.ImportName.empty() || (!E.Name.empty() && E.Name[0] == '?'))
                continue;
            E.SymbolName = E.Name;
            // Trim off the trailing decoration. Symbols will always have a
            // starting prefix here (either _ for cdecl/stdcall, @ for fastcall
            // or ? for C++ functions). Vectorcall functions won't have any
            // fixed prefix, but the function base name will still be at least
            // one char.
            E.Name = E.Name.substr(0, E.Name.find('@', 1));
            // By making sure E.SymbolName != E.Name for decorated symbols,
            // writeImportLibrary writes these symbols with the type
            // IMPORT_NAME_UNDECORATE.
        }
    }

    return static_cast<bool>(
        object::writeImportLibrary(def->OutputFile, output_lib_path,
                                   def->Exports, machine, /* MinGW */ true));
}

bool ZigLLVMWriteArchive(const char *archive_name, const char **file_names, size_t file_name_count,
    ZigLLVMArchiveKind archive_kind)
{
    SmallVector<NewArchiveMember, 4> new_members;
    for (size_t i = 0; i < file_name_count; i += 1) {
        Expected<NewArchiveMember> new_member = NewArchiveMember::getFile(file_names[i], true);
        Error err = new_member.takeError();
        if (err) return true;
        new_members.push_back(std::move(*new_member));
    }
    Error err = writeArchive(archive_name, new_members,
        SymtabWritingMode::NormalSymtab, static_cast<object::Archive::Kind>(archive_kind), true, false, nullptr);

    if (err) return true;
    return false;
}

// The header file in LLD 16 exposed these functions. As of 17 they are only
// exposed via a macro ("LLD_HAS_DRIVER") which I have copied and pasted the
// body of here so that you don't have to wonder what it is doing.
namespace lld {
    namespace coff {
        bool link(llvm::ArrayRef<const char *> args, llvm::raw_ostream &stdoutOS,
                llvm::raw_ostream &stderrOS, bool exitEarly, bool disableOutput);
    }
    namespace elf {
        bool link(llvm::ArrayRef<const char *> args, llvm::raw_ostream &stdoutOS,
                llvm::raw_ostream &stderrOS, bool exitEarly, bool disableOutput);
    }
    namespace wasm {
        bool link(llvm::ArrayRef<const char *> args, llvm::raw_ostream &stdoutOS,
                llvm::raw_ostream &stderrOS, bool exitEarly, bool disableOutput);
    }
}

bool ZigLLDLinkCOFF(int argc, const char **argv, bool can_exit_early, bool disable_output) {
    std::vector<const char *> args(argv, argv + argc);
    return lld::coff::link(args, llvm::outs(), llvm::errs(), can_exit_early, disable_output);
}

bool ZigLLDLinkELF(int argc, const char **argv, bool can_exit_early, bool disable_output) {
    std::vector<const char *> args(argv, argv + argc);
    return lld::elf::link(args, llvm::outs(), llvm::errs(), can_exit_early, disable_output);
}

bool ZigLLDLinkWasm(int argc, const char **argv, bool can_exit_early, bool disable_output) {
    std::vector<const char *> args(argv, argv + argc);
    return lld::wasm::link(args, llvm::outs(), llvm::errs(), can_exit_early, disable_output);
}

static_assert((FloatABI::ABIType)ZigLLVMFloatABI_Default == FloatABI::ABIType::Default, "");
static_assert((FloatABI::ABIType)ZigLLVMFloatABI_Soft == FloatABI::ABIType::Soft, "");
static_assert((FloatABI::ABIType)ZigLLVMFloatABI_Hard == FloatABI::ABIType::Hard, "");

static_assert((object::Archive::Kind)ZigLLVMArchiveKind_GNU == object::Archive::Kind::K_GNU, "");
static_assert((object::Archive::Kind)ZigLLVMArchiveKind_GNU64 == object::Archive::Kind::K_GNU64, "");
static_assert((object::Archive::Kind)ZigLLVMArchiveKind_BSD == object::Archive::Kind::K_BSD, "");
static_assert((object::Archive::Kind)ZigLLVMArchiveKind_DARWIN == object::Archive::Kind::K_DARWIN, "");
static_assert((object::Archive::Kind)ZigLLVMArchiveKind_DARWIN64 == object::Archive::Kind::K_DARWIN64, "");
static_assert((object::Archive::Kind)ZigLLVMArchiveKind_COFF == object::Archive::Kind::K_COFF, "");
static_assert((object::Archive::Kind)ZigLLVMArchiveKind_AIXBIG == object::Archive::Kind::K_AIXBIG, "");
