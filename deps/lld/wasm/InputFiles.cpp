//===- InputFiles.cpp -----------------------------------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "InputFiles.h"
#include "Config.h"
#include "InputChunks.h"
#include "InputEvent.h"
#include "InputGlobal.h"
#include "SymbolTable.h"
#include "lld/Common/ErrorHandler.h"
#include "lld/Common/Memory.h"
#include "llvm/Object/Binary.h"
#include "llvm/Object/Wasm.h"
#include "llvm/Support/raw_ostream.h"

#define DEBUG_TYPE "lld"

using namespace lld;
using namespace lld::wasm;

using namespace llvm;
using namespace llvm::object;
using namespace llvm::wasm;

Optional<MemoryBufferRef> lld::wasm::readFile(StringRef Path) {
  log("Loading: " + Path);

  auto MBOrErr = MemoryBuffer::getFile(Path);
  if (auto EC = MBOrErr.getError()) {
    error("cannot open " + Path + ": " + EC.message());
    return None;
  }
  std::unique_ptr<MemoryBuffer> &MB = *MBOrErr;
  MemoryBufferRef MBRef = MB->getMemBufferRef();
  make<std::unique_ptr<MemoryBuffer>>(std::move(MB)); // take MB ownership

  return MBRef;
}

InputFile *lld::wasm::createObjectFile(MemoryBufferRef MB) {
  file_magic Magic = identify_magic(MB.getBuffer());
  if (Magic == file_magic::wasm_object)
    return make<ObjFile>(MB);

  if (Magic == file_magic::bitcode)
    return make<BitcodeFile>(MB);

  fatal("unknown file type: " + MB.getBufferIdentifier());
}

void ObjFile::dumpInfo() const {
  log("info for: " + getName() +
      "\n              Symbols : " + Twine(Symbols.size()) +
      "\n     Function Imports : " + Twine(WasmObj->getNumImportedFunctions()) +
      "\n       Global Imports : " + Twine(WasmObj->getNumImportedGlobals()) +
      "\n        Event Imports : " + Twine(WasmObj->getNumImportedEvents()));
}

// Relocations contain either symbol or type indices.  This function takes a
// relocation and returns relocated index (i.e. translates from the input
// symbol/type space to the output symbol/type space).
uint32_t ObjFile::calcNewIndex(const WasmRelocation &Reloc) const {
  if (Reloc.Type == R_WEBASSEMBLY_TYPE_INDEX_LEB) {
    assert(TypeIsUsed[Reloc.Index]);
    return TypeMap[Reloc.Index];
  }
  return Symbols[Reloc.Index]->getOutputSymbolIndex();
}

// Relocations can contain addend for combined sections. This function takes a
// relocation and returns updated addend by offset in the output section.
uint32_t ObjFile::calcNewAddend(const WasmRelocation &Reloc) const {
  switch (Reloc.Type) {
  case R_WEBASSEMBLY_MEMORY_ADDR_LEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_SLEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_I32:
  case R_WEBASSEMBLY_FUNCTION_OFFSET_I32:
    return Reloc.Addend;
  case R_WEBASSEMBLY_SECTION_OFFSET_I32:
    return getSectionSymbol(Reloc.Index)->Section->OutputOffset + Reloc.Addend;
  default:
    llvm_unreachable("unexpected relocation type");
  }
}

// Calculate the value we expect to find at the relocation location.
// This is used as a sanity check before applying a relocation to a given
// location.  It is useful for catching bugs in the compiler and linker.
uint32_t ObjFile::calcExpectedValue(const WasmRelocation &Reloc) const {
  switch (Reloc.Type) {
  case R_WEBASSEMBLY_TABLE_INDEX_I32:
  case R_WEBASSEMBLY_TABLE_INDEX_SLEB: {
    const WasmSymbol &Sym = WasmObj->syms()[Reloc.Index];
    return TableEntries[Sym.Info.ElementIndex];
  }
  case R_WEBASSEMBLY_MEMORY_ADDR_SLEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_I32:
  case R_WEBASSEMBLY_MEMORY_ADDR_LEB: {
    const WasmSymbol &Sym = WasmObj->syms()[Reloc.Index];
    if (Sym.isUndefined())
      return 0;
    const WasmSegment &Segment =
        WasmObj->dataSegments()[Sym.Info.DataRef.Segment];
    return Segment.Data.Offset.Value.Int32 + Sym.Info.DataRef.Offset +
           Reloc.Addend;
  }
  case R_WEBASSEMBLY_FUNCTION_OFFSET_I32:
    if (auto *Sym = dyn_cast<DefinedFunction>(getFunctionSymbol(Reloc.Index))) {
      return Sym->Function->getFunctionInputOffset() +
             Sym->Function->getFunctionCodeOffset() + Reloc.Addend;
    }
    return 0;
  case R_WEBASSEMBLY_SECTION_OFFSET_I32:
    return Reloc.Addend;
  case R_WEBASSEMBLY_TYPE_INDEX_LEB:
    return Reloc.Index;
  case R_WEBASSEMBLY_FUNCTION_INDEX_LEB:
  case R_WEBASSEMBLY_GLOBAL_INDEX_LEB:
  case R_WEBASSEMBLY_EVENT_INDEX_LEB: {
    const WasmSymbol &Sym = WasmObj->syms()[Reloc.Index];
    return Sym.Info.ElementIndex;
  }
  default:
    llvm_unreachable("unknown relocation type");
  }
}

// Translate from the relocation's index into the final linked output value.
uint32_t ObjFile::calcNewValue(const WasmRelocation &Reloc) const {
  switch (Reloc.Type) {
  case R_WEBASSEMBLY_TABLE_INDEX_I32:
  case R_WEBASSEMBLY_TABLE_INDEX_SLEB:
    return getFunctionSymbol(Reloc.Index)->getTableIndex();
  case R_WEBASSEMBLY_MEMORY_ADDR_SLEB:
  case R_WEBASSEMBLY_MEMORY_ADDR_I32:
  case R_WEBASSEMBLY_MEMORY_ADDR_LEB:
    if (auto *Sym = dyn_cast<DefinedData>(getDataSymbol(Reloc.Index)))
      if (Sym->isLive())
        return Sym->getVirtualAddress() + Reloc.Addend;
    return 0;
  case R_WEBASSEMBLY_TYPE_INDEX_LEB:
    return TypeMap[Reloc.Index];
  case R_WEBASSEMBLY_FUNCTION_INDEX_LEB:
    return getFunctionSymbol(Reloc.Index)->getFunctionIndex();
  case R_WEBASSEMBLY_GLOBAL_INDEX_LEB:
    return getGlobalSymbol(Reloc.Index)->getGlobalIndex();
  case R_WEBASSEMBLY_EVENT_INDEX_LEB:
    return getEventSymbol(Reloc.Index)->getEventIndex();
  case R_WEBASSEMBLY_FUNCTION_OFFSET_I32:
    if (auto *Sym = dyn_cast<DefinedFunction>(getFunctionSymbol(Reloc.Index))) {
      if (Sym->isLive())
        return Sym->Function->OutputOffset +
               Sym->Function->getFunctionCodeOffset() + Reloc.Addend;
    }
    return 0;
  case R_WEBASSEMBLY_SECTION_OFFSET_I32:
    return getSectionSymbol(Reloc.Index)->Section->OutputOffset + Reloc.Addend;
  default:
    llvm_unreachable("unknown relocation type");
  }
}

template <class T>
static void setRelocs(const std::vector<T *> &Chunks,
                      const WasmSection *Section) {
  if (!Section)
    return;

  ArrayRef<WasmRelocation> Relocs = Section->Relocations;
  assert(std::is_sorted(Relocs.begin(), Relocs.end(),
                        [](const WasmRelocation &R1, const WasmRelocation &R2) {
                          return R1.Offset < R2.Offset;
                        }));
  assert(std::is_sorted(
      Chunks.begin(), Chunks.end(), [](InputChunk *C1, InputChunk *C2) {
        return C1->getInputSectionOffset() < C2->getInputSectionOffset();
      }));

  auto RelocsNext = Relocs.begin();
  auto RelocsEnd = Relocs.end();
  auto RelocLess = [](const WasmRelocation &R, uint32_t Val) {
    return R.Offset < Val;
  };
  for (InputChunk *C : Chunks) {
    auto RelocsStart = std::lower_bound(RelocsNext, RelocsEnd,
                                        C->getInputSectionOffset(), RelocLess);
    RelocsNext = std::lower_bound(
        RelocsStart, RelocsEnd, C->getInputSectionOffset() + C->getInputSize(),
        RelocLess);
    C->setRelocations(ArrayRef<WasmRelocation>(RelocsStart, RelocsNext));
  }
}

void ObjFile::parse() {
  // Parse a memory buffer as a wasm file.
  LLVM_DEBUG(dbgs() << "Parsing object: " << toString(this) << "\n");
  std::unique_ptr<Binary> Bin = CHECK(createBinary(MB), toString(this));

  auto *Obj = dyn_cast<WasmObjectFile>(Bin.get());
  if (!Obj)
    fatal(toString(this) + ": not a wasm file");
  if (!Obj->isRelocatableObject())
    fatal(toString(this) + ": not a relocatable wasm file");

  Bin.release();
  WasmObj.reset(Obj);

  // Build up a map of function indices to table indices for use when
  // verifying the existing table index relocations
  uint32_t TotalFunctions =
      WasmObj->getNumImportedFunctions() + WasmObj->functions().size();
  TableEntries.resize(TotalFunctions);
  for (const WasmElemSegment &Seg : WasmObj->elements()) {
    if (Seg.Offset.Opcode != WASM_OPCODE_I32_CONST)
      fatal(toString(this) + ": invalid table elements");
    uint32_t Offset = Seg.Offset.Value.Int32;
    for (uint32_t Index = 0; Index < Seg.Functions.size(); Index++) {

      uint32_t FunctionIndex = Seg.Functions[Index];
      TableEntries[FunctionIndex] = Offset + Index;
    }
  }

  // Find the code and data sections.  Wasm objects can have at most one code
  // and one data section.
  uint32_t SectionIndex = 0;
  for (const SectionRef &Sec : WasmObj->sections()) {
    const WasmSection &Section = WasmObj->getWasmSection(Sec);
    if (Section.Type == WASM_SEC_CODE) {
      CodeSection = &Section;
    } else if (Section.Type == WASM_SEC_DATA) {
      DataSection = &Section;
    } else if (Section.Type == WASM_SEC_CUSTOM) {
      CustomSections.emplace_back(make<InputSection>(Section, this));
      CustomSections.back()->setRelocations(Section.Relocations);
      CustomSectionsByIndex[SectionIndex] = CustomSections.back();
    }
    SectionIndex++;
  }

  TypeMap.resize(getWasmObj()->types().size());
  TypeIsUsed.resize(getWasmObj()->types().size(), false);

  ArrayRef<StringRef> Comdats = WasmObj->linkingData().Comdats;
  UsedComdats.resize(Comdats.size());
  for (unsigned I = 0; I < Comdats.size(); ++I)
    UsedComdats[I] = Symtab->addComdat(Comdats[I]);

  // Populate `Segments`.
  for (const WasmSegment &S : WasmObj->dataSegments())
    Segments.emplace_back(make<InputSegment>(S, this));
  setRelocs(Segments, DataSection);

  // Populate `Functions`.
  ArrayRef<WasmFunction> Funcs = WasmObj->functions();
  ArrayRef<uint32_t> FuncTypes = WasmObj->functionTypes();
  ArrayRef<WasmSignature> Types = WasmObj->types();
  Functions.reserve(Funcs.size());

  for (size_t I = 0, E = Funcs.size(); I != E; ++I)
    Functions.emplace_back(
        make<InputFunction>(Types[FuncTypes[I]], &Funcs[I], this));
  setRelocs(Functions, CodeSection);

  // Populate `Globals`.
  for (const WasmGlobal &G : WasmObj->globals())
    Globals.emplace_back(make<InputGlobal>(G, this));

  // Populate `Events`.
  for (const WasmEvent &E : WasmObj->events())
    Events.emplace_back(make<InputEvent>(Types[E.Type.SigIndex], E, this));

  // Populate `Symbols` based on the WasmSymbols in the object.
  Symbols.reserve(WasmObj->getNumberOfSymbols());
  for (const SymbolRef &Sym : WasmObj->symbols()) {
    const WasmSymbol &WasmSym = WasmObj->getWasmSymbol(Sym.getRawDataRefImpl());
    if (Symbol *Sym = createDefined(WasmSym))
      Symbols.push_back(Sym);
    else
      Symbols.push_back(createUndefined(WasmSym));
  }
}

bool ObjFile::isExcludedByComdat(InputChunk *Chunk) const {
  uint32_t C = Chunk->getComdat();
  if (C == UINT32_MAX)
    return false;
  return !UsedComdats[C];
}

FunctionSymbol *ObjFile::getFunctionSymbol(uint32_t Index) const {
  return cast<FunctionSymbol>(Symbols[Index]);
}

GlobalSymbol *ObjFile::getGlobalSymbol(uint32_t Index) const {
  return cast<GlobalSymbol>(Symbols[Index]);
}

EventSymbol *ObjFile::getEventSymbol(uint32_t Index) const {
  return cast<EventSymbol>(Symbols[Index]);
}

SectionSymbol *ObjFile::getSectionSymbol(uint32_t Index) const {
  return cast<SectionSymbol>(Symbols[Index]);
}

DataSymbol *ObjFile::getDataSymbol(uint32_t Index) const {
  return cast<DataSymbol>(Symbols[Index]);
}

Symbol *ObjFile::createDefined(const WasmSymbol &Sym) {
  if (!Sym.isDefined())
    return nullptr;

  StringRef Name = Sym.Info.Name;
  uint32_t Flags = Sym.Info.Flags;

  switch (Sym.Info.Kind) {
  case WASM_SYMBOL_TYPE_FUNCTION: {
    InputFunction *Func =
        Functions[Sym.Info.ElementIndex - WasmObj->getNumImportedFunctions()];
    if (isExcludedByComdat(Func)) {
      Func->Live = false;
      return nullptr;
    }

    if (Sym.isBindingLocal())
      return make<DefinedFunction>(Name, Flags, this, Func);
    return Symtab->addDefinedFunction(Name, Flags, this, Func);
  }
  case WASM_SYMBOL_TYPE_DATA: {
    InputSegment *Seg = Segments[Sym.Info.DataRef.Segment];
    if (isExcludedByComdat(Seg)) {
      Seg->Live = false;
      return nullptr;
    }

    uint32_t Offset = Sym.Info.DataRef.Offset;
    uint32_t Size = Sym.Info.DataRef.Size;

    if (Sym.isBindingLocal())
      return make<DefinedData>(Name, Flags, this, Seg, Offset, Size);
    return Symtab->addDefinedData(Name, Flags, this, Seg, Offset, Size);
  }
  case WASM_SYMBOL_TYPE_GLOBAL: {
    InputGlobal *Global =
        Globals[Sym.Info.ElementIndex - WasmObj->getNumImportedGlobals()];
    if (Sym.isBindingLocal())
      return make<DefinedGlobal>(Name, Flags, this, Global);
    return Symtab->addDefinedGlobal(Name, Flags, this, Global);
  }
  case WASM_SYMBOL_TYPE_SECTION: {
    InputSection *Section = CustomSectionsByIndex[Sym.Info.ElementIndex];
    assert(Sym.isBindingLocal());
    return make<SectionSymbol>(Name, Flags, Section, this);
  }
  case WASM_SYMBOL_TYPE_EVENT: {
    InputEvent *Event =
        Events[Sym.Info.ElementIndex - WasmObj->getNumImportedEvents()];
    if (Sym.isBindingLocal())
      return make<DefinedEvent>(Name, Flags, this, Event);
    return Symtab->addDefinedEvent(Name, Flags, this, Event);
  }
  }
  llvm_unreachable("unknown symbol kind");
}

Symbol *ObjFile::createUndefined(const WasmSymbol &Sym) {
  StringRef Name = Sym.Info.Name;
  uint32_t Flags = Sym.Info.Flags;

  switch (Sym.Info.Kind) {
  case WASM_SYMBOL_TYPE_FUNCTION:
    return Symtab->addUndefinedFunction(Name, Flags, this, Sym.Signature);
  case WASM_SYMBOL_TYPE_DATA:
    return Symtab->addUndefinedData(Name, Flags, this);
  case WASM_SYMBOL_TYPE_GLOBAL:
    return Symtab->addUndefinedGlobal(Name, Flags, this, Sym.GlobalType);
  case WASM_SYMBOL_TYPE_SECTION:
    llvm_unreachable("section symbols cannot be undefined");
  }
  llvm_unreachable("unknown symbol kind");
}

void ArchiveFile::parse() {
  // Parse a MemoryBufferRef as an archive file.
  LLVM_DEBUG(dbgs() << "Parsing library: " << toString(this) << "\n");
  File = CHECK(Archive::create(MB), toString(this));

  // Read the symbol table to construct Lazy symbols.
  int Count = 0;
  for (const Archive::Symbol &Sym : File->symbols()) {
    Symtab->addLazy(this, &Sym);
    ++Count;
  }
  LLVM_DEBUG(dbgs() << "Read " << Count << " symbols\n");
}

void ArchiveFile::addMember(const Archive::Symbol *Sym) {
  const Archive::Child &C =
      CHECK(Sym->getMember(),
            "could not get the member for symbol " + Sym->getName());

  // Don't try to load the same member twice (this can happen when members
  // mutually reference each other).
  if (!Seen.insert(C.getChildOffset()).second)
    return;

  LLVM_DEBUG(dbgs() << "loading lazy: " << Sym->getName() << "\n");
  LLVM_DEBUG(dbgs() << "from archive: " << toString(this) << "\n");

  MemoryBufferRef MB =
      CHECK(C.getMemoryBufferRef(),
            "could not get the buffer for the member defining symbol " +
                Sym->getName());

  InputFile *Obj = createObjectFile(MB);
  Obj->ArchiveName = getName();
  Symtab->addFile(Obj);
}

static uint8_t mapVisibility(GlobalValue::VisibilityTypes GvVisibility) {
  switch (GvVisibility) {
  case GlobalValue::DefaultVisibility:
    return WASM_SYMBOL_VISIBILITY_DEFAULT;
  case GlobalValue::HiddenVisibility:
  case GlobalValue::ProtectedVisibility:
    return WASM_SYMBOL_VISIBILITY_HIDDEN;
  }
  llvm_unreachable("unknown visibility");
}

static Symbol *createBitcodeSymbol(const lto::InputFile::Symbol &ObjSym,
                                   BitcodeFile &F) {
  StringRef Name = Saver.save(ObjSym.getName());

  uint32_t Flags = ObjSym.isWeak() ? WASM_SYMBOL_BINDING_WEAK : 0;
  Flags |= mapVisibility(ObjSym.getVisibility());

  if (ObjSym.isUndefined()) {
    if (ObjSym.isExecutable())
      return Symtab->addUndefinedFunction(Name, Flags, &F, nullptr);
    return Symtab->addUndefinedData(Name, Flags, &F);
  }

  if (ObjSym.isExecutable())
    return Symtab->addDefinedFunction(Name, Flags, &F, nullptr);
  return Symtab->addDefinedData(Name, Flags, &F, nullptr, 0, 0);
}

void BitcodeFile::parse() {
  Obj = check(lto::InputFile::create(MemoryBufferRef(
      MB.getBuffer(), Saver.save(ArchiveName + MB.getBufferIdentifier()))));
  Triple T(Obj->getTargetTriple());
  if (T.getArch() != Triple::wasm32) {
    error(toString(MB.getBufferIdentifier()) + ": machine type must be wasm32");
    return;
  }

  for (const lto::InputFile::Symbol &ObjSym : Obj->symbols())
    Symbols.push_back(createBitcodeSymbol(ObjSym, *this));
}

// Returns a string in the format of "foo.o" or "foo.a(bar.o)".
std::string lld::toString(const wasm::InputFile *File) {
  if (!File)
    return "<internal>";

  if (File->ArchiveName.empty())
    return File->getName();

  return (File->ArchiveName + "(" + File->getName() + ")").str();
}
