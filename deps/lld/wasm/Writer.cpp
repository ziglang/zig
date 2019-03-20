//===- Writer.cpp ---------------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "Writer.h"
#include "Config.h"
#include "InputChunks.h"
#include "InputEvent.h"
#include "InputGlobal.h"
#include "OutputSections.h"
#include "OutputSegment.h"
#include "SymbolTable.h"
#include "WriterUtils.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "lld/Common/Strings.h"
#include "lld/Common/Threads.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/BinaryFormat/Wasm.h"
#include "llvm/Object/WasmTraits.h"
#include "llvm/Support/FileOutputBuffer.h"
#include "llvm/Support/Format.h"
#include "llvm/Support/FormatVariadic.h"
#include "llvm/Support/LEB128.h"

#include <cstdarg>
#include <map>

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::wasm;
using namespace lld;
using namespace lld::wasm;

static constexpr int StackAlignment = 16;
static constexpr const char *FunctionTableName = "__indirect_function_table";
const char *lld::wasm::DefaultModule = "env";

namespace {

// An init entry to be written to either the synthetic init func or the
// linking metadata.
struct WasmInitEntry {
  const FunctionSymbol *Sym;
  uint32_t Priority;
};

// The writer writes a SymbolTable result to a file.
class Writer {
public:
  void run();

private:
  void openFile();

  uint32_t lookupType(const WasmSignature &Sig);
  uint32_t registerType(const WasmSignature &Sig);

  void createCtorFunction();
  void calculateInitFunctions();
  void assignIndexes();
  void calculateImports();
  void calculateExports();
  void calculateCustomSections();
  void assignSymtab();
  void calculateTypes();
  void createOutputSegments();
  void layoutMemory();
  void createHeader();
  void createSections();
  SyntheticSection *createSyntheticSection(uint32_t Type, StringRef Name = "");

  // Builtin sections
  void createTypeSection();
  void createFunctionSection();
  void createTableSection();
  void createGlobalSection();
  void createEventSection();
  void createExportSection();
  void createImportSection();
  void createMemorySection();
  void createElemSection();
  void createCodeSection();
  void createDataSection();
  void createCustomSections();

  // Custom sections
  void createDylinkSection();
  void createRelocSections();
  void createLinkingSection();
  void createNameSection();

  void writeHeader();
  void writeSections();

  uint64_t FileSize = 0;
  uint32_t TableBase = 0;
  uint32_t NumMemoryPages = 0;
  uint32_t MaxMemoryPages = 0;
  // Memory size and aligment. Written to the "dylink" section
  // when build with -shared or -pie.
  uint32_t MemAlign = 0;
  uint32_t MemSize = 0;

  std::vector<const WasmSignature *> Types;
  DenseMap<WasmSignature, int32_t> TypeIndices;
  std::vector<const Symbol *> ImportedSymbols;
  unsigned NumImportedFunctions = 0;
  unsigned NumImportedGlobals = 0;
  unsigned NumImportedEvents = 0;
  std::vector<WasmExport> Exports;
  std::vector<const DefinedData *> DefinedFakeGlobals;
  std::vector<InputGlobal *> InputGlobals;
  std::vector<InputFunction *> InputFunctions;
  std::vector<InputEvent *> InputEvents;
  std::vector<const FunctionSymbol *> IndirectFunctions;
  std::vector<const Symbol *> SymtabEntries;
  std::vector<WasmInitEntry> InitFunctions;

  llvm::StringMap<std::vector<InputSection *>> CustomSectionMapping;
  llvm::StringMap<SectionSymbol *> CustomSectionSymbols;

  // Elements that are used to construct the final output
  std::string Header;
  std::vector<OutputSection *> OutputSections;

  std::unique_ptr<FileOutputBuffer> Buffer;

  std::vector<OutputSegment *> Segments;
  llvm::SmallDenseMap<StringRef, OutputSegment *> SegmentMap;
};

} // anonymous namespace

void Writer::createImportSection() {
  uint32_t NumImports = ImportedSymbols.size();
  if (Config->ImportMemory)
    ++NumImports;
  if (Config->ImportTable)
    ++NumImports;

  if (NumImports == 0)
    return;

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_IMPORT);
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, NumImports, "import count");

  if (Config->ImportMemory) {
    WasmImport Import;
    Import.Module = DefaultModule;
    Import.Field = "memory";
    Import.Kind = WASM_EXTERNAL_MEMORY;
    Import.Memory.Flags = 0;
    Import.Memory.Initial = NumMemoryPages;
    if (MaxMemoryPages != 0) {
      Import.Memory.Flags |= WASM_LIMITS_FLAG_HAS_MAX;
      Import.Memory.Maximum = MaxMemoryPages;
    }
    if (Config->SharedMemory)
      Import.Memory.Flags |= WASM_LIMITS_FLAG_IS_SHARED;
    writeImport(OS, Import);
  }

  if (Config->ImportTable) {
    uint32_t TableSize = TableBase + IndirectFunctions.size();
    WasmImport Import;
    Import.Module = DefaultModule;
    Import.Field = FunctionTableName;
    Import.Kind = WASM_EXTERNAL_TABLE;
    Import.Table.ElemType = WASM_TYPE_FUNCREF;
    Import.Table.Limits = {0, TableSize, 0};
    writeImport(OS, Import);
  }

  for (const Symbol *Sym : ImportedSymbols) {
    WasmImport Import;
    if (auto *F = dyn_cast<UndefinedFunction>(Sym)) {
      Import.Field = F->ImportName;
      Import.Module = F->ImportModule;
    } else if (auto *G = dyn_cast<UndefinedGlobal>(Sym)) {
      Import.Field = G->ImportName;
      Import.Module = G->ImportModule;
    } else {
      Import.Field = Sym->getName();
      Import.Module = DefaultModule;
    }

    if (auto *FunctionSym = dyn_cast<FunctionSymbol>(Sym)) {
      Import.Kind = WASM_EXTERNAL_FUNCTION;
      Import.SigIndex = lookupType(*FunctionSym->Signature);
    } else if (auto *GlobalSym = dyn_cast<GlobalSymbol>(Sym)) {
      Import.Kind = WASM_EXTERNAL_GLOBAL;
      Import.Global = *GlobalSym->getGlobalType();
    } else {
      auto *EventSym = cast<EventSymbol>(Sym);
      Import.Kind = WASM_EXTERNAL_EVENT;
      Import.Event.Attribute = EventSym->getEventType()->Attribute;
      Import.Event.SigIndex = lookupType(*EventSym->Signature);
    }
    writeImport(OS, Import);
  }
}

void Writer::createTypeSection() {
  SyntheticSection *Section = createSyntheticSection(WASM_SEC_TYPE);
  raw_ostream &OS = Section->getStream();
  writeUleb128(OS, Types.size(), "type count");
  for (const WasmSignature *Sig : Types)
    writeSig(OS, *Sig);
}

void Writer::createFunctionSection() {
  if (InputFunctions.empty())
    return;

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_FUNCTION);
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, InputFunctions.size(), "function count");
  for (const InputFunction *Func : InputFunctions)
    writeUleb128(OS, lookupType(Func->Signature), "sig index");
}

void Writer::createMemorySection() {
  if (Config->ImportMemory)
    return;

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_MEMORY);
  raw_ostream &OS = Section->getStream();

  bool HasMax = MaxMemoryPages != 0;
  writeUleb128(OS, 1, "memory count");
  unsigned Flags = 0;
  if (HasMax)
    Flags |= WASM_LIMITS_FLAG_HAS_MAX;
  if (Config->SharedMemory)
    Flags |= WASM_LIMITS_FLAG_IS_SHARED;
  writeUleb128(OS, Flags, "memory limits flags");
  writeUleb128(OS, NumMemoryPages, "initial pages");
  if (HasMax)
    writeUleb128(OS, MaxMemoryPages, "max pages");
}

void Writer::createGlobalSection() {
  unsigned NumGlobals = InputGlobals.size() + DefinedFakeGlobals.size();
  if (NumGlobals == 0)
    return;

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_GLOBAL);
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, NumGlobals, "global count");
  for (const InputGlobal *G : InputGlobals)
    writeGlobal(OS, G->Global);
  for (const DefinedData *Sym : DefinedFakeGlobals) {
    WasmGlobal Global;
    Global.Type = {WASM_TYPE_I32, false};
    Global.InitExpr.Opcode = WASM_OPCODE_I32_CONST;
    Global.InitExpr.Value.Int32 = Sym->getVirtualAddress();
    writeGlobal(OS, Global);
  }
}

// The event section contains a list of declared wasm events associated with the
// module. Currently the only supported event kind is exceptions. A single event
// entry represents a single event with an event tag. All C++ exceptions are
// represented by a single event. An event entry in this section contains
// information on what kind of event it is (e.g. exception) and the type of
// values contained in a single event object. (In wasm, an event can contain
// multiple values of primitive types. But for C++ exceptions, we just throw a
// pointer which is an i32 value (for wasm32 architecture), so the signature of
// C++ exception is (i32)->(void), because all event types are assumed to have
// void return type to share WasmSignature with functions.)
void Writer::createEventSection() {
  unsigned NumEvents = InputEvents.size();
  if (NumEvents == 0)
    return;

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_EVENT);
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, NumEvents, "event count");
  for (InputEvent *E : InputEvents) {
    E->Event.Type.SigIndex = lookupType(E->Signature);
    writeEvent(OS, E->Event);
  }
}

void Writer::createTableSection() {
  if (Config->ImportTable)
    return;

  // Always output a table section (or table import), even if there are no
  // indirect calls.  There are two reasons for this:
  //  1. For executables it is useful to have an empty table slot at 0
  //     which can be filled with a null function call handler.
  //  2. If we don't do this, any program that contains a call_indirect but
  //     no address-taken function will fail at validation time since it is
  //     a validation error to include a call_indirect instruction if there
  //     is not table.
  uint32_t TableSize = TableBase + IndirectFunctions.size();

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_TABLE);
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, 1, "table count");
  WasmLimits Limits = {WASM_LIMITS_FLAG_HAS_MAX, TableSize, TableSize};
  writeTableType(OS, WasmTable{WASM_TYPE_FUNCREF, Limits});
}

void Writer::createExportSection() {
  if (!Exports.size())
    return;

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_EXPORT);
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, Exports.size(), "export count");
  for (const WasmExport &Export : Exports)
    writeExport(OS, Export);
}

void Writer::calculateCustomSections() {
  log("calculateCustomSections");
  bool StripDebug = Config->StripDebug || Config->StripAll;
  for (ObjFile *File : Symtab->ObjectFiles) {
    for (InputSection *Section : File->CustomSections) {
      StringRef Name = Section->getName();
      // These custom sections are known the linker and synthesized rather than
      // blindly copied
      if (Name == "linking" || Name == "name" || Name.startswith("reloc."))
        continue;
      // .. or it is a debug section
      if (StripDebug && Name.startswith(".debug_"))
        continue;
      CustomSectionMapping[Name].push_back(Section);
    }
  }
}

void Writer::createCustomSections() {
  log("createCustomSections");
  for (auto &Pair : CustomSectionMapping) {
    StringRef Name = Pair.first();

    auto P = CustomSectionSymbols.find(Name);
    if (P != CustomSectionSymbols.end()) {
      uint32_t SectionIndex = OutputSections.size();
      P->second->setOutputSectionIndex(SectionIndex);
    }

    LLVM_DEBUG(dbgs() << "createCustomSection: " << Name << "\n");
    OutputSections.push_back(make<CustomSection>(Name, Pair.second));
  }
}

void Writer::createElemSection() {
  if (IndirectFunctions.empty())
    return;

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_ELEM);
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, 1, "segment count");
  writeUleb128(OS, 0, "table index");
  WasmInitExpr InitExpr;
  if (Config->Pic) {
    InitExpr.Opcode = WASM_OPCODE_GLOBAL_GET;
    InitExpr.Value.Global = WasmSym::TableBase->getGlobalIndex();
  } else {
    InitExpr.Opcode = WASM_OPCODE_I32_CONST;
    InitExpr.Value.Int32 = TableBase;
  }
  writeInitExpr(OS, InitExpr);
  writeUleb128(OS, IndirectFunctions.size(), "elem count");

  uint32_t TableIndex = TableBase;
  for (const FunctionSymbol *Sym : IndirectFunctions) {
    assert(Sym->getTableIndex() == TableIndex);
    writeUleb128(OS, Sym->getFunctionIndex(), "function index");
    ++TableIndex;
  }
}

void Writer::createCodeSection() {
  if (InputFunctions.empty())
    return;

  log("createCodeSection");

  auto Section = make<CodeSection>(InputFunctions);
  OutputSections.push_back(Section);
}

void Writer::createDataSection() {
  if (!Segments.size())
    return;

  log("createDataSection");
  auto Section = make<DataSection>(Segments);
  OutputSections.push_back(Section);
}

// Create relocations sections in the final output.
// These are only created when relocatable output is requested.
void Writer::createRelocSections() {
  log("createRelocSections");
  // Don't use iterator here since we are adding to OutputSection
  size_t OrigSize = OutputSections.size();
  for (size_t I = 0; I < OrigSize; I++) {
    OutputSection *OSec = OutputSections[I];
    uint32_t Count = OSec->numRelocations();
    if (!Count)
      continue;

    StringRef Name;
    if (OSec->Type == WASM_SEC_DATA)
      Name = "reloc.DATA";
    else if (OSec->Type == WASM_SEC_CODE)
      Name = "reloc.CODE";
    else if (OSec->Type == WASM_SEC_CUSTOM)
      Name = Saver.save("reloc." + OSec->Name);
    else
      llvm_unreachable(
          "relocations only supported for code, data, or custom sections");

    SyntheticSection *Section = createSyntheticSection(WASM_SEC_CUSTOM, Name);
    raw_ostream &OS = Section->getStream();
    writeUleb128(OS, I, "reloc section");
    writeUleb128(OS, Count, "reloc count");
    OSec->writeRelocations(OS);
  }
}

static uint32_t getWasmFlags(const Symbol *Sym) {
  uint32_t Flags = 0;
  if (Sym->isLocal())
    Flags |= WASM_SYMBOL_BINDING_LOCAL;
  if (Sym->isWeak())
    Flags |= WASM_SYMBOL_BINDING_WEAK;
  if (Sym->isHidden())
    Flags |= WASM_SYMBOL_VISIBILITY_HIDDEN;
  if (Sym->isUndefined())
    Flags |= WASM_SYMBOL_UNDEFINED;
  if (auto *F = dyn_cast<UndefinedFunction>(Sym)) {
    if (F->getName() != F->ImportName)
      Flags |= WASM_SYMBOL_EXPLICIT_NAME;
  } else if (auto *G = dyn_cast<UndefinedGlobal>(Sym)) {
    if (G->getName() != G->ImportName)
      Flags |= WASM_SYMBOL_EXPLICIT_NAME;
  }
  return Flags;
}

// Some synthetic sections (e.g. "name" and "linking") have subsections.
// Just like the synthetic sections themselves these need to be created before
// they can be written out (since they are preceded by their length). This
// class is used to create subsections and then write them into the stream
// of the parent section.
class SubSection {
public:
  explicit SubSection(uint32_t Type) : Type(Type) {}

  void writeTo(raw_ostream &To) {
    OS.flush();
    writeUleb128(To, Type, "subsection type");
    writeUleb128(To, Body.size(), "subsection size");
    To.write(Body.data(), Body.size());
  }

private:
  uint32_t Type;
  std::string Body;

public:
  raw_string_ostream OS{Body};
};

// Create the custom "dylink" section containing information for the dynamic
// linker.
// See
// https://github.com/WebAssembly/tool-conventions/blob/master/DynamicLinking.md
void Writer::createDylinkSection() {
  SyntheticSection *Section = createSyntheticSection(WASM_SEC_CUSTOM, "dylink");
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, MemSize, "MemSize");
  writeUleb128(OS, MemAlign, "MemAlign");
  writeUleb128(OS, IndirectFunctions.size(), "TableSize");
  writeUleb128(OS, 0, "TableAlign");
  writeUleb128(OS, 0, "Needed");  // TODO: Support "needed" shared libraries
}

// Create the custom "linking" section containing linker metadata.
// This is only created when relocatable output is requested.
void Writer::createLinkingSection() {
  SyntheticSection *Section =
      createSyntheticSection(WASM_SEC_CUSTOM, "linking");
  raw_ostream &OS = Section->getStream();

  writeUleb128(OS, WasmMetadataVersion, "Version");

  if (!SymtabEntries.empty()) {
    SubSection Sub(WASM_SYMBOL_TABLE);
    writeUleb128(Sub.OS, SymtabEntries.size(), "num symbols");

    for (const Symbol *Sym : SymtabEntries) {
      assert(Sym->isDefined() || Sym->isUndefined());
      WasmSymbolType Kind = Sym->getWasmType();
      uint32_t Flags = getWasmFlags(Sym);

      writeU8(Sub.OS, Kind, "sym kind");
      writeUleb128(Sub.OS, Flags, "sym flags");

      if (auto *F = dyn_cast<FunctionSymbol>(Sym)) {
        writeUleb128(Sub.OS, F->getFunctionIndex(), "index");
        if (Sym->isDefined() ||
            (Flags & WASM_SYMBOL_EXPLICIT_NAME) != 0)
          writeStr(Sub.OS, Sym->getName(), "sym name");
      } else if (auto *G = dyn_cast<GlobalSymbol>(Sym)) {
        writeUleb128(Sub.OS, G->getGlobalIndex(), "index");
        if (Sym->isDefined() ||
            (Flags & WASM_SYMBOL_EXPLICIT_NAME) != 0)
          writeStr(Sub.OS, Sym->getName(), "sym name");
      } else if (auto *E = dyn_cast<EventSymbol>(Sym)) {
        writeUleb128(Sub.OS, E->getEventIndex(), "index");
        if (Sym->isDefined() ||
            (Flags & WASM_SYMBOL_EXPLICIT_NAME) != 0)
          writeStr(Sub.OS, Sym->getName(), "sym name");
      } else if (isa<DataSymbol>(Sym)) {
        writeStr(Sub.OS, Sym->getName(), "sym name");
        if (auto *DataSym = dyn_cast<DefinedData>(Sym)) {
          writeUleb128(Sub.OS, DataSym->getOutputSegmentIndex(), "index");
          writeUleb128(Sub.OS, DataSym->getOutputSegmentOffset(),
                       "data offset");
          writeUleb128(Sub.OS, DataSym->getSize(), "data size");
        }
      } else {
        auto *S = cast<SectionSymbol>(Sym);
        writeUleb128(Sub.OS, S->getOutputSectionIndex(), "sym section index");
      }
    }

    Sub.writeTo(OS);
  }

  if (Segments.size()) {
    SubSection Sub(WASM_SEGMENT_INFO);
    writeUleb128(Sub.OS, Segments.size(), "num data segments");
    for (const OutputSegment *S : Segments) {
      writeStr(Sub.OS, S->Name, "segment name");
      writeUleb128(Sub.OS, S->Alignment, "alignment");
      writeUleb128(Sub.OS, 0, "flags");
    }
    Sub.writeTo(OS);
  }

  if (!InitFunctions.empty()) {
    SubSection Sub(WASM_INIT_FUNCS);
    writeUleb128(Sub.OS, InitFunctions.size(), "num init functions");
    for (const WasmInitEntry &F : InitFunctions) {
      writeUleb128(Sub.OS, F.Priority, "priority");
      writeUleb128(Sub.OS, F.Sym->getOutputSymbolIndex(), "function index");
    }
    Sub.writeTo(OS);
  }

  struct ComdatEntry {
    unsigned Kind;
    uint32_t Index;
  };
  std::map<StringRef, std::vector<ComdatEntry>> Comdats;

  for (const InputFunction *F : InputFunctions) {
    StringRef Comdat = F->getComdatName();
    if (!Comdat.empty())
      Comdats[Comdat].emplace_back(
          ComdatEntry{WASM_COMDAT_FUNCTION, F->getFunctionIndex()});
  }
  for (uint32_t I = 0; I < Segments.size(); ++I) {
    const auto &InputSegments = Segments[I]->InputSegments;
    if (InputSegments.empty())
      continue;
    StringRef Comdat = InputSegments[0]->getComdatName();
#ifndef NDEBUG
    for (const InputSegment *IS : InputSegments)
      assert(IS->getComdatName() == Comdat);
#endif
    if (!Comdat.empty())
      Comdats[Comdat].emplace_back(ComdatEntry{WASM_COMDAT_DATA, I});
  }

  if (!Comdats.empty()) {
    SubSection Sub(WASM_COMDAT_INFO);
    writeUleb128(Sub.OS, Comdats.size(), "num comdats");
    for (const auto &C : Comdats) {
      writeStr(Sub.OS, C.first, "comdat name");
      writeUleb128(Sub.OS, 0, "comdat flags"); // flags for future use
      writeUleb128(Sub.OS, C.second.size(), "num entries");
      for (const ComdatEntry &Entry : C.second) {
        writeU8(Sub.OS, Entry.Kind, "entry kind");
        writeUleb128(Sub.OS, Entry.Index, "entry index");
      }
    }
    Sub.writeTo(OS);
  }
}

// Create the custom "name" section containing debug symbol names.
void Writer::createNameSection() {
  unsigned NumNames = NumImportedFunctions;
  for (const InputFunction *F : InputFunctions)
    if (!F->getName().empty() || !F->getDebugName().empty())
      ++NumNames;

  if (NumNames == 0)
    return;

  SyntheticSection *Section = createSyntheticSection(WASM_SEC_CUSTOM, "name");

  SubSection Sub(WASM_NAMES_FUNCTION);
  writeUleb128(Sub.OS, NumNames, "name count");

  // Names must appear in function index order.  As it happens ImportedSymbols
  // and InputFunctions are numbered in order with imported functions coming
  // first.
  for (const Symbol *S : ImportedSymbols) {
    if (auto *F = dyn_cast<FunctionSymbol>(S)) {
      writeUleb128(Sub.OS, F->getFunctionIndex(), "func index");
      writeStr(Sub.OS, toString(*S), "symbol name");
    }
  }
  for (const InputFunction *F : InputFunctions) {
    if (!F->getName().empty()) {
      writeUleb128(Sub.OS, F->getFunctionIndex(), "func index");
      if (!F->getDebugName().empty()) {
        writeStr(Sub.OS, F->getDebugName(), "symbol name");
      } else {
        writeStr(Sub.OS, maybeDemangleSymbol(F->getName()), "symbol name");
      }
    }
  }

  Sub.writeTo(Section->getStream());
}

void Writer::writeHeader() {
  memcpy(Buffer->getBufferStart(), Header.data(), Header.size());
}

void Writer::writeSections() {
  uint8_t *Buf = Buffer->getBufferStart();
  parallelForEach(OutputSections, [Buf](OutputSection *S) { S->writeTo(Buf); });
}

// Fix the memory layout of the output binary.  This assigns memory offsets
// to each of the input data sections as well as the explicit stack region.
// The default memory layout is as follows, from low to high.
//
//  - initialized data (starting at Config->GlobalBase)
//  - BSS data (not currently implemented in llvm)
//  - explicit stack (Config->ZStackSize)
//  - heap start / unallocated
//
// The --stack-first option means that stack is placed before any static data.
// This can be useful since it means that stack overflow traps immediately
// rather than overwriting global data, but also increases code size since all
// static data loads and stores requires larger offsets.
void Writer::layoutMemory() {
  createOutputSegments();

  uint32_t MemoryPtr = 0;

  auto PlaceStack = [&]() {
    if (Config->Relocatable || Config->Shared)
      return;
    MemoryPtr = alignTo(MemoryPtr, StackAlignment);
    if (Config->ZStackSize != alignTo(Config->ZStackSize, StackAlignment))
      error("stack size must be " + Twine(StackAlignment) + "-byte aligned");
    log("mem: stack size  = " + Twine(Config->ZStackSize));
    log("mem: stack base  = " + Twine(MemoryPtr));
    MemoryPtr += Config->ZStackSize;
    auto *SP = cast<DefinedGlobal>(WasmSym::StackPointer);
    SP->Global->Global.InitExpr.Value.Int32 = MemoryPtr;
    log("mem: stack top   = " + Twine(MemoryPtr));
  };

  if (Config->StackFirst) {
    PlaceStack();
  } else {
    MemoryPtr = Config->GlobalBase;
    log("mem: global base = " + Twine(Config->GlobalBase));
  }

  uint32_t DataStart = MemoryPtr;

  // Arbitrarily set __dso_handle handle to point to the start of the data
  // segments.
  if (WasmSym::DsoHandle)
    WasmSym::DsoHandle->setVirtualAddress(DataStart);

  MemAlign = 0;
  for (OutputSegment *Seg : Segments) {
    MemAlign = std::max(MemAlign, Seg->Alignment);
    MemoryPtr = alignTo(MemoryPtr, 1 << Seg->Alignment);
    Seg->StartVA = MemoryPtr;
    log(formatv("mem: {0,-15} offset={1,-8} size={2,-8} align={3}", Seg->Name,
                MemoryPtr, Seg->Size, Seg->Alignment));
    MemoryPtr += Seg->Size;
  }

  // TODO: Add .bss space here.
  if (WasmSym::DataEnd)
    WasmSym::DataEnd->setVirtualAddress(MemoryPtr);

  log("mem: static data = " + Twine(MemoryPtr - DataStart));

  if (Config->Shared) {
    MemSize = MemoryPtr;
    return;
  }

  if (!Config->StackFirst)
    PlaceStack();

  // Set `__heap_base` to directly follow the end of the stack or global data.
  // The fact that this comes last means that a malloc/brk implementation
  // can grow the heap at runtime.
  if (!Config->Relocatable) {
    WasmSym::HeapBase->setVirtualAddress(MemoryPtr);
    log("mem: heap base   = " + Twine(MemoryPtr));
  }

  if (Config->InitialMemory != 0) {
    if (Config->InitialMemory != alignTo(Config->InitialMemory, WasmPageSize))
      error("initial memory must be " + Twine(WasmPageSize) + "-byte aligned");
    if (MemoryPtr > Config->InitialMemory)
      error("initial memory too small, " + Twine(MemoryPtr) + " bytes needed");
    else
      MemoryPtr = Config->InitialMemory;
  }
  MemSize = MemoryPtr;
  NumMemoryPages = alignTo(MemoryPtr, WasmPageSize) / WasmPageSize;
  log("mem: total pages = " + Twine(NumMemoryPages));

  if (Config->MaxMemory != 0) {
    if (Config->MaxMemory != alignTo(Config->MaxMemory, WasmPageSize))
      error("maximum memory must be " + Twine(WasmPageSize) + "-byte aligned");
    if (MemoryPtr > Config->MaxMemory)
      error("maximum memory too small, " + Twine(MemoryPtr) + " bytes needed");
    MaxMemoryPages = Config->MaxMemory / WasmPageSize;
    log("mem: max pages   = " + Twine(MaxMemoryPages));
  }
}

SyntheticSection *Writer::createSyntheticSection(uint32_t Type,
                                                 StringRef Name) {
  auto Sec = make<SyntheticSection>(Type, Name);
  log("createSection: " + toString(*Sec));
  OutputSections.push_back(Sec);
  return Sec;
}

void Writer::createSections() {
  // Known sections
  if (Config->Pic)
    createDylinkSection();
  createTypeSection();
  createImportSection();
  createFunctionSection();
  createTableSection();
  createMemorySection();
  createGlobalSection();
  createEventSection();
  createExportSection();
  createElemSection();
  createCodeSection();
  createDataSection();
  createCustomSections();

  // Custom sections
  if (Config->Relocatable) {
    createLinkingSection();
    createRelocSections();
  }
  if (!Config->StripDebug && !Config->StripAll)
    createNameSection();

  for (OutputSection *S : OutputSections) {
    S->setOffset(FileSize);
    S->finalizeContents();
    FileSize += S->getSize();
  }
}

void Writer::calculateImports() {
  for (Symbol *Sym : Symtab->getSymbols()) {
    if (!Sym->isUndefined())
      continue;
    if (isa<DataSymbol>(Sym))
      continue;
    if (Sym->isWeak() && !Config->Relocatable)
      continue;
    if (!Sym->isLive())
      continue;
    if (!Sym->IsUsedInRegularObj)
      continue;

    LLVM_DEBUG(dbgs() << "import: " << Sym->getName() << "\n");
    ImportedSymbols.emplace_back(Sym);
    if (auto *F = dyn_cast<FunctionSymbol>(Sym))
      F->setFunctionIndex(NumImportedFunctions++);
    else if (auto *G = dyn_cast<GlobalSymbol>(Sym))
      G->setGlobalIndex(NumImportedGlobals++);
    else
      cast<EventSymbol>(Sym)->setEventIndex(NumImportedEvents++);
  }
}

void Writer::calculateExports() {
  if (Config->Relocatable)
    return;

  if (!Config->Relocatable && !Config->ImportMemory)
    Exports.push_back(WasmExport{"memory", WASM_EXTERNAL_MEMORY, 0});

  if (!Config->Relocatable && Config->ExportTable)
    Exports.push_back(WasmExport{FunctionTableName, WASM_EXTERNAL_TABLE, 0});

  unsigned FakeGlobalIndex = NumImportedGlobals + InputGlobals.size();

  for (Symbol *Sym : Symtab->getSymbols()) {
    if (!Sym->isExported())
      continue;
    if (!Sym->isLive())
      continue;

    StringRef Name = Sym->getName();
    WasmExport Export;
    if (auto *F = dyn_cast<DefinedFunction>(Sym)) {
      Export = {Name, WASM_EXTERNAL_FUNCTION, F->getFunctionIndex()};
    } else if (auto *G = dyn_cast<DefinedGlobal>(Sym)) {
      // TODO(sbc): Remove this check once to mutable global proposal is
      // implement in all major browsers.
      // See: https://github.com/WebAssembly/mutable-global
      if (G->getGlobalType()->Mutable) {
        // Only the __stack_pointer should ever be create as mutable.
        assert(G == WasmSym::StackPointer);
        continue;
      }
      Export = {Name, WASM_EXTERNAL_GLOBAL, G->getGlobalIndex()};
    } else if (auto *E = dyn_cast<DefinedEvent>(Sym)) {
      Export = {Name, WASM_EXTERNAL_EVENT, E->getEventIndex()};
    } else {
      auto *D = cast<DefinedData>(Sym);
      DefinedFakeGlobals.emplace_back(D);
      Export = {Name, WASM_EXTERNAL_GLOBAL, FakeGlobalIndex++};
    }

    LLVM_DEBUG(dbgs() << "Export: " << Name << "\n");
    Exports.push_back(Export);
  }
}

void Writer::assignSymtab() {
  if (!Config->Relocatable)
    return;

  StringMap<uint32_t> SectionSymbolIndices;

  unsigned SymbolIndex = SymtabEntries.size();

  auto AddSymbol = [&](Symbol *Sym) {
    if (auto *S = dyn_cast<SectionSymbol>(Sym)) {
      StringRef Name = S->getName();
      if (CustomSectionMapping.count(Name) == 0)
        return;

      auto SSI = SectionSymbolIndices.find(Name);
      if (SSI != SectionSymbolIndices.end()) {
        Sym->setOutputSymbolIndex(SSI->second);
        return;
      }

      SectionSymbolIndices[Name] = SymbolIndex;
      CustomSectionSymbols[Name] = cast<SectionSymbol>(Sym);

      Sym->markLive();
    }

    // (Since this is relocatable output, GC is not performed so symbols must
    // be live.)
    assert(Sym->isLive());
    Sym->setOutputSymbolIndex(SymbolIndex++);
    SymtabEntries.emplace_back(Sym);
  };

  for (Symbol *Sym : Symtab->getSymbols())
    if (!Sym->isLazy())
      AddSymbol(Sym);

  for (ObjFile *File : Symtab->ObjectFiles) {
    LLVM_DEBUG(dbgs() << "Local symtab entries: " << File->getName() << "\n");
    for (Symbol *Sym : File->getSymbols())
      if (Sym->isLocal())
        AddSymbol(Sym);
  }
}

uint32_t Writer::lookupType(const WasmSignature &Sig) {
  auto It = TypeIndices.find(Sig);
  if (It == TypeIndices.end()) {
    error("type not found: " + toString(Sig));
    return 0;
  }
  return It->second;
}

uint32_t Writer::registerType(const WasmSignature &Sig) {
  auto Pair = TypeIndices.insert(std::make_pair(Sig, Types.size()));
  if (Pair.second) {
    LLVM_DEBUG(dbgs() << "type " << toString(Sig) << "\n");
    Types.push_back(&Sig);
  }
  return Pair.first->second;
}

void Writer::calculateTypes() {
  // The output type section is the union of the following sets:
  // 1. Any signature used in the TYPE relocation
  // 2. The signatures of all imported functions
  // 3. The signatures of all defined functions
  // 4. The signatures of all imported events
  // 5. The signatures of all defined events

  for (ObjFile *File : Symtab->ObjectFiles) {
    ArrayRef<WasmSignature> Types = File->getWasmObj()->types();
    for (uint32_t I = 0; I < Types.size(); I++)
      if (File->TypeIsUsed[I])
        File->TypeMap[I] = registerType(Types[I]);
  }

  for (const Symbol *Sym : ImportedSymbols) {
    if (auto *F = dyn_cast<FunctionSymbol>(Sym))
      registerType(*F->Signature);
    else if (auto *E = dyn_cast<EventSymbol>(Sym))
      registerType(*E->Signature);
  }

  for (const InputFunction *F : InputFunctions)
    registerType(F->Signature);

  for (const InputEvent *E : InputEvents)
    registerType(E->Signature);
}

void Writer::assignIndexes() {
  assert(InputFunctions.empty());
  uint32_t FunctionIndex = NumImportedFunctions;
  auto AddDefinedFunction = [&](InputFunction *Func) {
    if (!Func->Live)
      return;
    InputFunctions.emplace_back(Func);
    Func->setFunctionIndex(FunctionIndex++);
  };

  for (InputFunction *Func : Symtab->SyntheticFunctions)
    AddDefinedFunction(Func);

  for (ObjFile *File : Symtab->ObjectFiles) {
    LLVM_DEBUG(dbgs() << "Functions: " << File->getName() << "\n");
    for (InputFunction *Func : File->Functions)
      AddDefinedFunction(Func);
  }

  uint32_t TableIndex = TableBase;
  auto HandleRelocs = [&](InputChunk *Chunk) {
    if (!Chunk->Live)
      return;
    ObjFile *File = Chunk->File;
    ArrayRef<WasmSignature> Types = File->getWasmObj()->types();
    for (const WasmRelocation &Reloc : Chunk->getRelocations()) {
      if (Reloc.Type == R_WEBASSEMBLY_TABLE_INDEX_I32 ||
          Reloc.Type == R_WEBASSEMBLY_TABLE_INDEX_SLEB) {
        FunctionSymbol *Sym = File->getFunctionSymbol(Reloc.Index);
        if (Sym->hasTableIndex() || !Sym->hasFunctionIndex())
          continue;
        Sym->setTableIndex(TableIndex++);
        IndirectFunctions.emplace_back(Sym);
      } else if (Reloc.Type == R_WEBASSEMBLY_TYPE_INDEX_LEB) {
        // Mark target type as live
        File->TypeMap[Reloc.Index] = registerType(Types[Reloc.Index]);
        File->TypeIsUsed[Reloc.Index] = true;
      }
    }
  };

  for (ObjFile *File : Symtab->ObjectFiles) {
    LLVM_DEBUG(dbgs() << "Handle relocs: " << File->getName() << "\n");
    for (InputChunk *Chunk : File->Functions)
      HandleRelocs(Chunk);
    for (InputChunk *Chunk : File->Segments)
      HandleRelocs(Chunk);
    for (auto &P : File->CustomSections)
      HandleRelocs(P);
  }

  assert(InputGlobals.empty());
  uint32_t GlobalIndex = NumImportedGlobals;
  auto AddDefinedGlobal = [&](InputGlobal *Global) {
    if (Global->Live) {
      LLVM_DEBUG(dbgs() << "AddDefinedGlobal: " << GlobalIndex << "\n");
      Global->setGlobalIndex(GlobalIndex++);
      InputGlobals.push_back(Global);
    }
  };

  for (InputGlobal *Global : Symtab->SyntheticGlobals)
    AddDefinedGlobal(Global);

  for (ObjFile *File : Symtab->ObjectFiles) {
    LLVM_DEBUG(dbgs() << "Globals: " << File->getName() << "\n");
    for (InputGlobal *Global : File->Globals)
      AddDefinedGlobal(Global);
  }

  assert(InputEvents.empty());
  uint32_t EventIndex = NumImportedEvents;
  auto AddDefinedEvent = [&](InputEvent *Event) {
    if (Event->Live) {
      LLVM_DEBUG(dbgs() << "AddDefinedEvent: " << EventIndex << "\n");
      Event->setEventIndex(EventIndex++);
      InputEvents.push_back(Event);
    }
  };

  for (ObjFile *File : Symtab->ObjectFiles) {
    LLVM_DEBUG(dbgs() << "Events: " << File->getName() << "\n");
    for (InputEvent *Event : File->Events)
      AddDefinedEvent(Event);
  }
}

static StringRef getOutputDataSegmentName(StringRef Name) {
  // With PIC code we currently only support a single data segment since
  // we only have a single __memory_base to use as our base address.
  if (Config->Pic)
    return "data";
  if (!Config->MergeDataSegments)
    return Name;
  if (Name.startswith(".text."))
    return ".text";
  if (Name.startswith(".data."))
    return ".data";
  if (Name.startswith(".bss."))
    return ".bss";
  if (Name.startswith(".rodata."))
    return ".rodata";
  return Name;
}

void Writer::createOutputSegments() {
  for (ObjFile *File : Symtab->ObjectFiles) {
    for (InputSegment *Segment : File->Segments) {
      if (!Segment->Live)
        continue;
      StringRef Name = getOutputDataSegmentName(Segment->getName());
      OutputSegment *&S = SegmentMap[Name];
      if (S == nullptr) {
        LLVM_DEBUG(dbgs() << "new segment: " << Name << "\n");
        S = make<OutputSegment>(Name, Segments.size());
        Segments.push_back(S);
      }
      S->addInputSegment(Segment);
      LLVM_DEBUG(dbgs() << "added data: " << Name << ": " << S->Size << "\n");
    }
  }
}

static const int OPCODE_CALL = 0x10;
static const int OPCODE_END = 0xb;

// Create synthetic "__wasm_call_ctors" function based on ctor functions
// in input object.
void Writer::createCtorFunction() {
  // First write the body's contents to a string.
  std::string BodyContent;
  {
    raw_string_ostream OS(BodyContent);
    writeUleb128(OS, 0, "num locals");
    for (const WasmInitEntry &F : InitFunctions) {
      writeU8(OS, OPCODE_CALL, "CALL");
      writeUleb128(OS, F.Sym->getFunctionIndex(), "function index");
    }
    writeU8(OS, OPCODE_END, "END");
  }

  // Once we know the size of the body we can create the final function body
  std::string FunctionBody;
  {
    raw_string_ostream OS(FunctionBody);
    writeUleb128(OS, BodyContent.size(), "function size");
    OS << BodyContent;
  }

  ArrayRef<uint8_t> Body = arrayRefFromStringRef(Saver.save(FunctionBody));
  cast<SyntheticFunction>(WasmSym::CallCtors->Function)->setBody(Body);
}

// Populate InitFunctions vector with init functions from all input objects.
// This is then used either when creating the output linking section or to
// synthesize the "__wasm_call_ctors" function.
void Writer::calculateInitFunctions() {
  for (ObjFile *File : Symtab->ObjectFiles) {
    const WasmLinkingData &L = File->getWasmObj()->linkingData();
    for (const WasmInitFunc &F : L.InitFunctions) {
      FunctionSymbol *Sym = File->getFunctionSymbol(F.Symbol);
      if (*Sym->Signature != WasmSignature{{}, {}})
        error("invalid signature for init func: " + toString(*Sym));
      InitFunctions.emplace_back(WasmInitEntry{Sym, F.Priority});
    }
  }

  // Sort in order of priority (lowest first) so that they are called
  // in the correct order.
  std::stable_sort(InitFunctions.begin(), InitFunctions.end(),
                   [](const WasmInitEntry &L, const WasmInitEntry &R) {
                     return L.Priority < R.Priority;
                   });
}

void Writer::run() {
  if (Config->Relocatable || Config->Pic)
    Config->GlobalBase = 0;

  // For PIC code the table base is assigned dynamically by the loader.
  // For non-PIC, we start at 1 so that accessing table index 0 always traps.
  if (!Config->Pic)
    TableBase = 1;

  log("-- calculateImports");
  calculateImports();
  log("-- assignIndexes");
  assignIndexes();
  log("-- calculateInitFunctions");
  calculateInitFunctions();
  if (!Config->Relocatable)
    createCtorFunction();
  log("-- calculateTypes");
  calculateTypes();
  log("-- layoutMemory");
  layoutMemory();
  log("-- calculateExports");
  calculateExports();
  log("-- calculateCustomSections");
  calculateCustomSections();
  log("-- assignSymtab");
  assignSymtab();

  if (errorHandler().Verbose) {
    log("Defined Functions: " + Twine(InputFunctions.size()));
    log("Defined Globals  : " + Twine(InputGlobals.size()));
    log("Defined Events   : " + Twine(InputEvents.size()));
    log("Function Imports : " + Twine(NumImportedFunctions));
    log("Global Imports   : " + Twine(NumImportedGlobals));
    log("Event Imports    : " + Twine(NumImportedEvents));
    for (ObjFile *File : Symtab->ObjectFiles)
      File->dumpInfo();
  }

  createHeader();
  log("-- createSections");
  createSections();

  log("-- openFile");
  openFile();
  if (errorCount())
    return;

  writeHeader();

  log("-- writeSections");
  writeSections();
  if (errorCount())
    return;

  if (Error E = Buffer->commit())
    fatal("failed to write the output file: " + toString(std::move(E)));
}

// Open a result file.
void Writer::openFile() {
  log("writing: " + Config->OutputFile);

  Expected<std::unique_ptr<FileOutputBuffer>> BufferOrErr =
      FileOutputBuffer::create(Config->OutputFile, FileSize,
                               FileOutputBuffer::F_executable);

  if (!BufferOrErr)
    error("failed to open " + Config->OutputFile + ": " +
          toString(BufferOrErr.takeError()));
  else
    Buffer = std::move(*BufferOrErr);
}

void Writer::createHeader() {
  raw_string_ostream OS(Header);
  writeBytes(OS, WasmMagic, sizeof(WasmMagic), "wasm magic");
  writeU32(OS, WasmVersion, "wasm version");
  OS.flush();
  FileSize += Header.size();
}

void lld::wasm::writeResult() { Writer().run(); }
