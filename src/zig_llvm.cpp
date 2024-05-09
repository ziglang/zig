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
#include <llvm/Target/CodeGenCWrappers.h>
#include <llvm/Transforms/IPO.h>
#include <llvm/Transforms/IPO/AlwaysInliner.h>
#include <llvm/Transforms/Instrumentation/ThreadSanitizer.h>
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
    LLVMCodeModel CodeModel, bool function_sections, bool data_sections, ZigLLVMABIType float_abi, 
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

    opt.FunctionSections = function_sections;
    opt.DataSections = data_sections;
    switch (float_abi) {
        case ZigLLVMABITypeDefault:
            opt.FloatABIType = FloatABI::Default;
            break;
        case ZigLLVMABITypeSoft:
            opt.FloatABIType = FloatABI::Soft;
            break;
        case ZigLLVMABITypeHard:
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

bool ZigLLVMTargetMachineEmitToFile(LLVMTargetMachineRef targ_machine_ref, LLVMModuleRef module_ref,
        char **error_message, bool is_debug,
        bool is_small, bool time_report, bool tsan, bool lto,
        const char *asm_filename, const char *bin_filename,
        const char *llvm_ir_filename, const char *bitcode_filename)
{
    TimePassesIsEnabled = time_report;

    raw_fd_ostream *dest_asm_ptr = nullptr;
    raw_fd_ostream *dest_bin_ptr = nullptr;
    raw_fd_ostream *dest_bitcode_ptr = nullptr;

    if (asm_filename) {
        std::error_code EC;
        dest_asm_ptr = new(std::nothrow) raw_fd_ostream(asm_filename, EC, sys::fs::OF_None);
        if (EC) {
            *error_message = strdup((const char *)StringRef(EC.message()).bytes_begin());
            return true;
        }
    }
    if (bin_filename) {
        std::error_code EC;
        dest_bin_ptr = new(std::nothrow) raw_fd_ostream(bin_filename, EC, sys::fs::OF_None);
        if (EC) {
            *error_message = strdup((const char *)StringRef(EC.message()).bytes_begin());
            return true;
        }
    }
    if (bitcode_filename) {
        std::error_code EC;
        dest_bitcode_ptr = new(std::nothrow) raw_fd_ostream(bitcode_filename, EC, sys::fs::OF_None);
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
                              bin_filename? bin_filename : asm_filename);

    TargetMachine &target_machine = *reinterpret_cast<TargetMachine*>(targ_machine_ref);
    target_machine.setO0WantsFastISel(true);

    Module &llvm_module = *unwrap(module_ref);

    // Pipeline configurations
    PipelineTuningOptions pipeline_opts;
    pipeline_opts.LoopUnrolling = !is_debug;
    pipeline_opts.SLPVectorization = !is_debug;
    pipeline_opts.LoopVectorization = !is_debug;
    pipeline_opts.LoopInterleaving = !is_debug;
    pipeline_opts.MergeFunctions = !is_debug;

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
    pass_builder.crossRegisterProxies(loop_am, function_am,
                                      cgscc_am, module_am);

    // IR verification
    if (assertions_on) {
      // Verify the input
      pass_builder.registerPipelineStartEPCallback(
        [](ModulePassManager &module_pm, OptimizationLevel OL) {
          module_pm.addPass(VerifierPass());
        });
      // Verify the output
      pass_builder.registerOptimizerLastEPCallback(
        [](ModulePassManager &module_pm, OptimizationLevel OL) {
          module_pm.addPass(VerifierPass());
        });
    }

    // Passes specific for release build
    if (!is_debug) {
      pass_builder.registerPipelineStartEPCallback(
        [](ModulePassManager &module_pm, OptimizationLevel OL) {
          module_pm.addPass(
            createModuleToFunctionPassAdaptor(AddDiscriminatorsPass()));
        });
    }

    // Thread sanitizer
    if (tsan) {
        pass_builder.registerOptimizerLastEPCallback([](ModulePassManager &module_pm, OptimizationLevel level) {
            module_pm.addPass(ModuleThreadSanitizerPass());
            module_pm.addPass(createModuleToFunctionPassAdaptor(ThreadSanitizerPass()));
        });
    }

    ModulePassManager module_pm;
    OptimizationLevel opt_level;
    // Setting up the optimization level
    if (is_debug)
      opt_level = OptimizationLevel::O0;
    else if (is_small)
      opt_level = OptimizationLevel::Oz;
    else
      opt_level = OptimizationLevel::O3;

    // Initialize the PassManager
    if (opt_level == OptimizationLevel::O0) {
      module_pm = pass_builder.buildO0DefaultPipeline(opt_level, lto);
    } else if (lto) {
      module_pm = pass_builder.buildLTOPreLinkDefaultPipeline(opt_level);
    } else {
      module_pm = pass_builder.buildPerModuleDefaultPipeline(opt_level);
    }

    // Unfortunately we don't have new PM for code generation
    legacy::PassManager codegen_pm;
    codegen_pm.add(
      createTargetTransformInfoWrapperPass(target_machine.getTargetIRAnalysis()));

    if (dest_bin && !lto) {
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

    // Optimization phase
    module_pm.run(llvm_module, module_am);

    // Code generation phase
    codegen_pm.run(llvm_module);

    if (llvm_ir_filename) {
        if (LLVMPrintModuleToFile(module_ref, llvm_ir_filename, error_message)) {
            return true;
        }
    }

    if (dest_bin && lto) {
        WriteBitcodeToFile(llvm_module, *dest_bin);
    }
    if (dest_bitcode) {
        WriteBitcodeToFile(llvm_module, *dest_bitcode);
    }

    if (time_report) {
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

void ZigLLVMSetModulePICLevel(LLVMModuleRef module) {
    unwrap(module)->setPICLevel(PICLevel::Level::BigPIC);
}

void ZigLLVMSetModulePIELevel(LLVMModuleRef module) {
    unwrap(module)->setPIELevel(PIELevel::Level::Large);
}

void ZigLLVMSetModuleCodeModel(LLVMModuleRef module, LLVMCodeModel code_model) {
    bool JIT;
    unwrap(module)->setCodeModel(*unwrap(code_model, JIT));
    assert(!JIT);
}

bool ZigLLVMWriteImportLibrary(const char *def_path, const ZigLLVM_ArchType arch,
                               const char *output_lib_path, bool kill_at)
{
    COFF::MachineTypes machine = COFF::IMAGE_FILE_MACHINE_UNKNOWN;

    switch (arch) {
        case ZigLLVM_x86:
            machine = COFF::IMAGE_FILE_MACHINE_I386;
            break;
        case ZigLLVM_x86_64:
            machine = COFF::IMAGE_FILE_MACHINE_AMD64;
            break;
        case ZigLLVM_arm:
        case ZigLLVM_armeb:
        case ZigLLVM_thumb:
        case ZigLLVM_thumbeb:
            machine = COFF::IMAGE_FILE_MACHINE_ARMNT;
            break;
        case ZigLLVM_aarch64:
        case ZigLLVM_aarch64_be:
            machine = COFF::IMAGE_FILE_MACHINE_ARM64;
            break;
        default:
            break;
    }

    if (machine == COFF::IMAGE_FILE_MACHINE_UNKNOWN) {
        return true;
    }

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

    // The exports-juggling code below is ripped from LLVM's DllToolDriver.cpp

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
            if (!E.AliasTarget.empty() || (!E.Name.empty() && E.Name[0] == '?'))
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
        ZigLLVM_OSType os_type)
{
    object::Archive::Kind kind;
    switch (os_type) {
        case ZigLLVM_Win32:
            // For some reason llvm-lib passes K_GNU on windows.
            // See lib/ToolDrivers/llvm-lib/LibDriver.cpp:168 in libDriverMain
            kind = object::Archive::K_GNU;
            break;
        case ZigLLVM_Linux:
            kind = object::Archive::K_GNU;
            break;
        case ZigLLVM_MacOSX:
        case ZigLLVM_Darwin:
        case ZigLLVM_IOS:
            kind = object::Archive::K_DARWIN;
            break;
        case ZigLLVM_OpenBSD:
        case ZigLLVM_FreeBSD:
            kind = object::Archive::K_BSD;
            break;
        default:
            kind = object::Archive::K_GNU;
    }
    SmallVector<NewArchiveMember, 4> new_members;
    for (size_t i = 0; i < file_name_count; i += 1) {
        Expected<NewArchiveMember> new_member = NewArchiveMember::getFile(file_names[i], true);
        Error err = new_member.takeError();
        if (err) return true;
        new_members.push_back(std::move(*new_member));
    }
    Error err = writeArchive(archive_name, new_members,
        SymtabWritingMode::NormalSymtab, kind, true, false, nullptr);

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

static_assert((Triple::ArchType)ZigLLVM_UnknownArch == Triple::UnknownArch, "");
static_assert((Triple::ArchType)ZigLLVM_arm == Triple::arm, "");
static_assert((Triple::ArchType)ZigLLVM_armeb == Triple::armeb, "");
static_assert((Triple::ArchType)ZigLLVM_aarch64 == Triple::aarch64, "");
static_assert((Triple::ArchType)ZigLLVM_aarch64_be == Triple::aarch64_be, "");
static_assert((Triple::ArchType)ZigLLVM_aarch64_32 == Triple::aarch64_32, "");
static_assert((Triple::ArchType)ZigLLVM_arc == Triple::arc, "");
static_assert((Triple::ArchType)ZigLLVM_avr == Triple::avr, "");
static_assert((Triple::ArchType)ZigLLVM_bpfel == Triple::bpfel, "");
static_assert((Triple::ArchType)ZigLLVM_bpfeb == Triple::bpfeb, "");
static_assert((Triple::ArchType)ZigLLVM_csky == Triple::csky, "");
static_assert((Triple::ArchType)ZigLLVM_hexagon == Triple::hexagon, "");
static_assert((Triple::ArchType)ZigLLVM_m68k == Triple::m68k, "");
static_assert((Triple::ArchType)ZigLLVM_mips == Triple::mips, "");
static_assert((Triple::ArchType)ZigLLVM_mipsel == Triple::mipsel, "");
static_assert((Triple::ArchType)ZigLLVM_mips64 == Triple::mips64, "");
static_assert((Triple::ArchType)ZigLLVM_mips64el == Triple::mips64el, "");
static_assert((Triple::ArchType)ZigLLVM_msp430 == Triple::msp430, "");
static_assert((Triple::ArchType)ZigLLVM_ppc == Triple::ppc, "");
static_assert((Triple::ArchType)ZigLLVM_ppcle == Triple::ppcle, "");
static_assert((Triple::ArchType)ZigLLVM_ppc64 == Triple::ppc64, "");
static_assert((Triple::ArchType)ZigLLVM_ppc64le == Triple::ppc64le, "");
static_assert((Triple::ArchType)ZigLLVM_r600 == Triple::r600, "");
static_assert((Triple::ArchType)ZigLLVM_amdgcn == Triple::amdgcn, "");
static_assert((Triple::ArchType)ZigLLVM_riscv32 == Triple::riscv32, "");
static_assert((Triple::ArchType)ZigLLVM_riscv64 == Triple::riscv64, "");
static_assert((Triple::ArchType)ZigLLVM_sparc == Triple::sparc, "");
static_assert((Triple::ArchType)ZigLLVM_sparcv9 == Triple::sparcv9, "");
static_assert((Triple::ArchType)ZigLLVM_sparcel == Triple::sparcel, "");
static_assert((Triple::ArchType)ZigLLVM_systemz == Triple::systemz, "");
static_assert((Triple::ArchType)ZigLLVM_tce == Triple::tce, "");
static_assert((Triple::ArchType)ZigLLVM_tcele == Triple::tcele, "");
static_assert((Triple::ArchType)ZigLLVM_thumb == Triple::thumb, "");
static_assert((Triple::ArchType)ZigLLVM_thumbeb == Triple::thumbeb, "");
static_assert((Triple::ArchType)ZigLLVM_x86 == Triple::x86, "");
static_assert((Triple::ArchType)ZigLLVM_x86_64 == Triple::x86_64, "");
static_assert((Triple::ArchType)ZigLLVM_xcore == Triple::xcore, "");
static_assert((Triple::ArchType)ZigLLVM_xtensa == Triple::xtensa, "");
static_assert((Triple::ArchType)ZigLLVM_nvptx == Triple::nvptx, "");
static_assert((Triple::ArchType)ZigLLVM_nvptx64 == Triple::nvptx64, "");
static_assert((Triple::ArchType)ZigLLVM_le32 == Triple::le32, "");
static_assert((Triple::ArchType)ZigLLVM_le64 == Triple::le64, "");
static_assert((Triple::ArchType)ZigLLVM_amdil == Triple::amdil, "");
static_assert((Triple::ArchType)ZigLLVM_amdil64 == Triple::amdil64, "");
static_assert((Triple::ArchType)ZigLLVM_hsail == Triple::hsail, "");
static_assert((Triple::ArchType)ZigLLVM_hsail64 == Triple::hsail64, "");
static_assert((Triple::ArchType)ZigLLVM_spir == Triple::spir, "");
static_assert((Triple::ArchType)ZigLLVM_spir64 == Triple::spir64, "");
static_assert((Triple::ArchType)ZigLLVM_spirv == Triple::spirv, "");
static_assert((Triple::ArchType)ZigLLVM_spirv32 == Triple::spirv32, "");
static_assert((Triple::ArchType)ZigLLVM_spirv64 == Triple::spirv64, "");
static_assert((Triple::ArchType)ZigLLVM_kalimba == Triple::kalimba, "");
static_assert((Triple::ArchType)ZigLLVM_shave == Triple::shave, "");
static_assert((Triple::ArchType)ZigLLVM_lanai == Triple::lanai, "");
static_assert((Triple::ArchType)ZigLLVM_wasm32 == Triple::wasm32, "");
static_assert((Triple::ArchType)ZigLLVM_wasm64 == Triple::wasm64, "");
static_assert((Triple::ArchType)ZigLLVM_renderscript32 == Triple::renderscript32, "");
static_assert((Triple::ArchType)ZigLLVM_renderscript64 == Triple::renderscript64, "");
static_assert((Triple::ArchType)ZigLLVM_ve == Triple::ve, "");
static_assert((Triple::ArchType)ZigLLVM_LastArchType == Triple::LastArchType, "");

static_assert((Triple::VendorType)ZigLLVM_UnknownVendor == Triple::UnknownVendor, "");
static_assert((Triple::VendorType)ZigLLVM_Apple == Triple::Apple, "");
static_assert((Triple::VendorType)ZigLLVM_PC == Triple::PC, "");
static_assert((Triple::VendorType)ZigLLVM_SCEI == Triple::SCEI, "");
static_assert((Triple::VendorType)ZigLLVM_Freescale == Triple::Freescale, "");
static_assert((Triple::VendorType)ZigLLVM_IBM == Triple::IBM, "");
static_assert((Triple::VendorType)ZigLLVM_ImaginationTechnologies == Triple::ImaginationTechnologies, "");
static_assert((Triple::VendorType)ZigLLVM_MipsTechnologies == Triple::MipsTechnologies, "");
static_assert((Triple::VendorType)ZigLLVM_NVIDIA == Triple::NVIDIA, "");
static_assert((Triple::VendorType)ZigLLVM_CSR == Triple::CSR, "");
static_assert((Triple::VendorType)ZigLLVM_AMD == Triple::AMD, "");
static_assert((Triple::VendorType)ZigLLVM_Mesa == Triple::Mesa, "");
static_assert((Triple::VendorType)ZigLLVM_SUSE == Triple::SUSE, "");
static_assert((Triple::VendorType)ZigLLVM_OpenEmbedded == Triple::OpenEmbedded, "");
static_assert((Triple::VendorType)ZigLLVM_LastVendorType == Triple::LastVendorType, "");

static_assert((Triple::OSType)ZigLLVM_UnknownOS == Triple::UnknownOS, "");
static_assert((Triple::OSType)ZigLLVM_Darwin == Triple::Darwin, "");
static_assert((Triple::OSType)ZigLLVM_DragonFly == Triple::DragonFly, "");
static_assert((Triple::OSType)ZigLLVM_FreeBSD == Triple::FreeBSD, "");
static_assert((Triple::OSType)ZigLLVM_Fuchsia == Triple::Fuchsia, "");
static_assert((Triple::OSType)ZigLLVM_IOS == Triple::IOS, "");
// Commented out to work around a Debian/Ubuntu bug.
// See https://github.com/ziglang/zig/issues/2076
//static_assert((Triple::OSType)ZigLLVM_KFreeBSD == Triple::KFreeBSD, "");
static_assert((Triple::OSType)ZigLLVM_Linux == Triple::Linux, "");
static_assert((Triple::OSType)ZigLLVM_Lv2 == Triple::Lv2, "");
static_assert((Triple::OSType)ZigLLVM_MacOSX == Triple::MacOSX, "");
static_assert((Triple::OSType)ZigLLVM_NetBSD == Triple::NetBSD, "");
static_assert((Triple::OSType)ZigLLVM_OpenBSD == Triple::OpenBSD, "");
static_assert((Triple::OSType)ZigLLVM_Solaris == Triple::Solaris, "");
static_assert((Triple::OSType)ZigLLVM_UEFI == Triple::UEFI, "");
static_assert((Triple::OSType)ZigLLVM_Win32 == Triple::Win32, "");
static_assert((Triple::OSType)ZigLLVM_ZOS == Triple::ZOS, "");
static_assert((Triple::OSType)ZigLLVM_Haiku == Triple::Haiku, "");
static_assert((Triple::OSType)ZigLLVM_RTEMS == Triple::RTEMS, "");
static_assert((Triple::OSType)ZigLLVM_NaCl == Triple::NaCl, "");
static_assert((Triple::OSType)ZigLLVM_AIX == Triple::AIX, "");
static_assert((Triple::OSType)ZigLLVM_CUDA == Triple::CUDA, "");
static_assert((Triple::OSType)ZigLLVM_NVCL == Triple::NVCL, "");
static_assert((Triple::OSType)ZigLLVM_AMDHSA == Triple::AMDHSA, "");
static_assert((Triple::OSType)ZigLLVM_PS4 == Triple::PS4, "");
static_assert((Triple::OSType)ZigLLVM_ELFIAMCU == Triple::ELFIAMCU, "");
static_assert((Triple::OSType)ZigLLVM_TvOS == Triple::TvOS, "");
static_assert((Triple::OSType)ZigLLVM_WatchOS == Triple::WatchOS, "");
static_assert((Triple::OSType)ZigLLVM_DriverKit == Triple::DriverKit, "");
static_assert((Triple::OSType)ZigLLVM_XROS == Triple::XROS, "");
static_assert((Triple::OSType)ZigLLVM_Mesa3D == Triple::Mesa3D, "");
static_assert((Triple::OSType)ZigLLVM_AMDPAL == Triple::AMDPAL, "");
static_assert((Triple::OSType)ZigLLVM_HermitCore == Triple::HermitCore, "");
static_assert((Triple::OSType)ZigLLVM_Hurd == Triple::Hurd, "");
static_assert((Triple::OSType)ZigLLVM_WASI == Triple::WASI, "");
static_assert((Triple::OSType)ZigLLVM_Emscripten == Triple::Emscripten, "");
static_assert((Triple::OSType)ZigLLVM_ShaderModel == Triple::ShaderModel, "");
static_assert((Triple::OSType)ZigLLVM_LiteOS == Triple::LiteOS, "");
static_assert((Triple::OSType)ZigLLVM_Serenity == Triple::Serenity, "");
static_assert((Triple::OSType)ZigLLVM_Vulkan == Triple::Vulkan, "");
static_assert((Triple::OSType)ZigLLVM_LastOSType == Triple::LastOSType, "");

static_assert((Triple::EnvironmentType)ZigLLVM_UnknownEnvironment == Triple::UnknownEnvironment, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNU == Triple::GNU, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUABIN32 == Triple::GNUABIN32, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUABI64 == Triple::GNUABI64, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUEABI == Triple::GNUEABI, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUEABIHF == Triple::GNUEABIHF, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUF32 == Triple::GNUF32, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUF64 == Triple::GNUF64, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUSF == Triple::GNUSF, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUX32 == Triple::GNUX32, "");
static_assert((Triple::EnvironmentType)ZigLLVM_GNUILP32 == Triple::GNUILP32, "");
static_assert((Triple::EnvironmentType)ZigLLVM_CODE16 == Triple::CODE16, "");
static_assert((Triple::EnvironmentType)ZigLLVM_EABI == Triple::EABI, "");
static_assert((Triple::EnvironmentType)ZigLLVM_EABIHF == Triple::EABIHF, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Android == Triple::Android, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Musl == Triple::Musl, "");
static_assert((Triple::EnvironmentType)ZigLLVM_MuslEABI == Triple::MuslEABI, "");
static_assert((Triple::EnvironmentType)ZigLLVM_MuslEABIHF == Triple::MuslEABIHF, "");
static_assert((Triple::EnvironmentType)ZigLLVM_MuslX32 == Triple::MuslX32, "");
static_assert((Triple::EnvironmentType)ZigLLVM_MSVC == Triple::MSVC, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Itanium == Triple::Itanium, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Cygnus == Triple::Cygnus, "");
static_assert((Triple::EnvironmentType)ZigLLVM_CoreCLR == Triple::CoreCLR, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Simulator == Triple::Simulator, "");
static_assert((Triple::EnvironmentType)ZigLLVM_MacABI == Triple::MacABI, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Pixel == Triple::Pixel, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Vertex == Triple::Vertex, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Geometry == Triple::Geometry, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Hull == Triple::Hull, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Domain == Triple::Domain, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Compute == Triple::Compute, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Library == Triple::Library, "");
static_assert((Triple::EnvironmentType)ZigLLVM_RayGeneration == Triple::RayGeneration, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Intersection == Triple::Intersection, "");
static_assert((Triple::EnvironmentType)ZigLLVM_AnyHit == Triple::AnyHit, "");
static_assert((Triple::EnvironmentType)ZigLLVM_ClosestHit == Triple::ClosestHit, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Miss == Triple::Miss, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Callable == Triple::Callable, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Mesh == Triple::Mesh, "");
static_assert((Triple::EnvironmentType)ZigLLVM_Amplification == Triple::Amplification, "");
static_assert((Triple::EnvironmentType)ZigLLVM_OpenHOS == Triple::OpenHOS, "");
static_assert((Triple::EnvironmentType)ZigLLVM_LastEnvironmentType == Triple::LastEnvironmentType, "");

static_assert((Triple::ObjectFormatType)ZigLLVM_UnknownObjectFormat == Triple::UnknownObjectFormat, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_COFF == Triple::COFF, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_ELF == Triple::ELF, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_GOFF == Triple::GOFF, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_MachO == Triple::MachO, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_Wasm == Triple::Wasm, "");
static_assert((Triple::ObjectFormatType)ZigLLVM_XCOFF == Triple::XCOFF, "");

static_assert((CallingConv::ID)ZigLLVM_C == llvm::CallingConv::C, "");
static_assert((CallingConv::ID)ZigLLVM_Fast == llvm::CallingConv::Fast, "");
static_assert((CallingConv::ID)ZigLLVM_Cold == llvm::CallingConv::Cold, "");
static_assert((CallingConv::ID)ZigLLVM_GHC == llvm::CallingConv::GHC, "");
static_assert((CallingConv::ID)ZigLLVM_HiPE == llvm::CallingConv::HiPE, "");
static_assert((CallingConv::ID)ZigLLVM_AnyReg == llvm::CallingConv::AnyReg, "");
static_assert((CallingConv::ID)ZigLLVM_PreserveMost == llvm::CallingConv::PreserveMost, "");
static_assert((CallingConv::ID)ZigLLVM_PreserveAll == llvm::CallingConv::PreserveAll, "");
static_assert((CallingConv::ID)ZigLLVM_Swift == llvm::CallingConv::Swift, "");
static_assert((CallingConv::ID)ZigLLVM_CXX_FAST_TLS == llvm::CallingConv::CXX_FAST_TLS, "");
static_assert((CallingConv::ID)ZigLLVM_Tail == llvm::CallingConv::Tail, "");
static_assert((CallingConv::ID)ZigLLVM_CFGuard_Check == llvm::CallingConv::CFGuard_Check, "");
static_assert((CallingConv::ID)ZigLLVM_SwiftTail == llvm::CallingConv::SwiftTail, "");
static_assert((CallingConv::ID)ZigLLVM_FirstTargetCC == llvm::CallingConv::FirstTargetCC, "");
static_assert((CallingConv::ID)ZigLLVM_X86_StdCall == llvm::CallingConv::X86_StdCall, "");
static_assert((CallingConv::ID)ZigLLVM_X86_FastCall == llvm::CallingConv::X86_FastCall, "");
static_assert((CallingConv::ID)ZigLLVM_ARM_APCS == llvm::CallingConv::ARM_APCS, "");
static_assert((CallingConv::ID)ZigLLVM_ARM_AAPCS == llvm::CallingConv::ARM_AAPCS, "");
static_assert((CallingConv::ID)ZigLLVM_ARM_AAPCS_VFP == llvm::CallingConv::ARM_AAPCS_VFP, "");
static_assert((CallingConv::ID)ZigLLVM_MSP430_INTR == llvm::CallingConv::MSP430_INTR, "");
static_assert((CallingConv::ID)ZigLLVM_X86_ThisCall == llvm::CallingConv::X86_ThisCall, "");
static_assert((CallingConv::ID)ZigLLVM_PTX_Kernel == llvm::CallingConv::PTX_Kernel, "");
static_assert((CallingConv::ID)ZigLLVM_PTX_Device == llvm::CallingConv::PTX_Device, "");
static_assert((CallingConv::ID)ZigLLVM_SPIR_FUNC == llvm::CallingConv::SPIR_FUNC, "");
static_assert((CallingConv::ID)ZigLLVM_SPIR_KERNEL == llvm::CallingConv::SPIR_KERNEL, "");
static_assert((CallingConv::ID)ZigLLVM_Intel_OCL_BI == llvm::CallingConv::Intel_OCL_BI, "");
static_assert((CallingConv::ID)ZigLLVM_X86_64_SysV == llvm::CallingConv::X86_64_SysV, "");
static_assert((CallingConv::ID)ZigLLVM_Win64 == llvm::CallingConv::Win64, "");
static_assert((CallingConv::ID)ZigLLVM_X86_VectorCall == llvm::CallingConv::X86_VectorCall, "");
static_assert((CallingConv::ID)ZigLLVM_DUMMY_HHVM == llvm::CallingConv::DUMMY_HHVM, "");
static_assert((CallingConv::ID)ZigLLVM_DUMMY_HHVM_C == llvm::CallingConv::DUMMY_HHVM_C, "");
static_assert((CallingConv::ID)ZigLLVM_X86_INTR == llvm::CallingConv::X86_INTR, "");
static_assert((CallingConv::ID)ZigLLVM_AVR_INTR == llvm::CallingConv::AVR_INTR, "");
static_assert((CallingConv::ID)ZigLLVM_AVR_SIGNAL == llvm::CallingConv::AVR_SIGNAL, "");
static_assert((CallingConv::ID)ZigLLVM_AVR_BUILTIN == llvm::CallingConv::AVR_BUILTIN, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_VS == llvm::CallingConv::AMDGPU_VS, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_GS == llvm::CallingConv::AMDGPU_GS, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_PS == llvm::CallingConv::AMDGPU_PS, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_CS == llvm::CallingConv::AMDGPU_CS, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_KERNEL == llvm::CallingConv::AMDGPU_KERNEL, "");
static_assert((CallingConv::ID)ZigLLVM_X86_RegCall == llvm::CallingConv::X86_RegCall, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_HS == llvm::CallingConv::AMDGPU_HS, "");
static_assert((CallingConv::ID)ZigLLVM_MSP430_BUILTIN == llvm::CallingConv::MSP430_BUILTIN, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_LS == llvm::CallingConv::AMDGPU_LS, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_ES == llvm::CallingConv::AMDGPU_ES, "");
static_assert((CallingConv::ID)ZigLLVM_AArch64_VectorCall == llvm::CallingConv::AArch64_VectorCall, "");
static_assert((CallingConv::ID)ZigLLVM_AArch64_SVE_VectorCall == llvm::CallingConv::AArch64_SVE_VectorCall, "");
static_assert((CallingConv::ID)ZigLLVM_WASM_EmscriptenInvoke == llvm::CallingConv::WASM_EmscriptenInvoke, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_Gfx == llvm::CallingConv::AMDGPU_Gfx, "");
static_assert((CallingConv::ID)ZigLLVM_M68k_INTR == llvm::CallingConv::M68k_INTR, "");
static_assert((CallingConv::ID)ZigLLVM_AArch64_SME_ABI_Support_Routines_PreserveMost_From_X0 == llvm::CallingConv::AArch64_SME_ABI_Support_Routines_PreserveMost_From_X0, "");
static_assert((CallingConv::ID)ZigLLVM_AArch64_SME_ABI_Support_Routines_PreserveMost_From_X2 == llvm::CallingConv::AArch64_SME_ABI_Support_Routines_PreserveMost_From_X2, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_CS_Chain == llvm::CallingConv::AMDGPU_CS_Chain, "");
static_assert((CallingConv::ID)ZigLLVM_AMDGPU_CS_ChainPreserve == llvm::CallingConv::AMDGPU_CS_ChainPreserve, "");
static_assert((CallingConv::ID)ZigLLVM_M68k_RTD == llvm::CallingConv::M68k_RTD, "");
static_assert((CallingConv::ID)ZigLLVM_GRAAL == llvm::CallingConv::GRAAL, "");
static_assert((CallingConv::ID)ZigLLVM_ARM64EC_Thunk_X64 == llvm::CallingConv::ARM64EC_Thunk_X64, "");
static_assert((CallingConv::ID)ZigLLVM_ARM64EC_Thunk_Native == llvm::CallingConv::ARM64EC_Thunk_Native, "");
static_assert((CallingConv::ID)ZigLLVM_MaxID == llvm::CallingConv::MaxID, "");
