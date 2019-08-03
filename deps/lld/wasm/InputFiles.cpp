//===- InputFiles.cpp -----------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
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
#include "lld/Common/Reproduce.h"
#include "llvm/Object/Binary.h"
#include "llvm/Object/Wasm.h"
#include "llvm/Support/TarWriter.h"
#include "llvm/Support/raw_ostream.h"

#define DEBUG_TYPE "lld"

using namespace lld;
using namespace lld::wasm;

using namespace llvm;
using namespace llvm::object;
using namespace llvm::wasm;

std::unique_ptr<llvm::TarWriter> lld::wasm::tar;

Optional<MemoryBufferRef> lld::wasm::readFile(StringRef path) {
  log("Loading: " + path);

  auto mbOrErr = MemoryBuffer::getFile(path);
  if (auto ec = mbOrErr.getError()) {
    error("cannot open " + path + ": " + ec.message());
    return None;
  }
  std::unique_ptr<MemoryBuffer> &mb = *mbOrErr;
  MemoryBufferRef mbref = mb->getMemBufferRef();
  make<std::unique_ptr<MemoryBuffer>>(std::move(mb)); // take MB ownership

  if (tar)
    tar->append(relativeToRoot(path), mbref.getBuffer());
  return mbref;
}

InputFile *lld::wasm::createObjectFile(MemoryBufferRef mb,
                                       StringRef archiveName) {
  file_magic magic = identify_magic(mb.getBuffer());
  if (magic == file_magic::wasm_object) {
    std::unique_ptr<Binary> bin =
        CHECK(createBinary(mb), mb.getBufferIdentifier());
    auto *obj = cast<WasmObjectFile>(bin.get());
    if (obj->isSharedObject())
      return make<SharedFile>(mb);
    return make<ObjFile>(mb, archiveName);
  }

  if (magic == file_magic::bitcode)
    return make<BitcodeFile>(mb, archiveName);

  fatal("unknown file type: " + mb.getBufferIdentifier());
}

void ObjFile::dumpInfo() const {
  log("info for: " + toString(this) +
      "\n              Symbols : " + Twine(symbols.size()) +
      "\n     Function Imports : " + Twine(wasmObj->getNumImportedFunctions()) +
      "\n       Global Imports : " + Twine(wasmObj->getNumImportedGlobals()) +
      "\n        Event Imports : " + Twine(wasmObj->getNumImportedEvents()));
}

// Relocations contain either symbol or type indices.  This function takes a
// relocation and returns relocated index (i.e. translates from the input
// symbol/type space to the output symbol/type space).
uint32_t ObjFile::calcNewIndex(const WasmRelocation &reloc) const {
  if (reloc.Type == R_WASM_TYPE_INDEX_LEB) {
    assert(typeIsUsed[reloc.Index]);
    return typeMap[reloc.Index];
  }
  const Symbol *sym = symbols[reloc.Index];
  if (auto *ss = dyn_cast<SectionSymbol>(sym))
    sym = ss->getOutputSectionSymbol();
  return sym->getOutputSymbolIndex();
}

// Relocations can contain addend for combined sections. This function takes a
// relocation and returns updated addend by offset in the output section.
uint32_t ObjFile::calcNewAddend(const WasmRelocation &reloc) const {
  switch (reloc.Type) {
  case R_WASM_MEMORY_ADDR_LEB:
  case R_WASM_MEMORY_ADDR_SLEB:
  case R_WASM_MEMORY_ADDR_REL_SLEB:
  case R_WASM_MEMORY_ADDR_I32:
  case R_WASM_FUNCTION_OFFSET_I32:
    return reloc.Addend;
  case R_WASM_SECTION_OFFSET_I32:
    return getSectionSymbol(reloc.Index)->section->outputOffset + reloc.Addend;
  default:
    llvm_unreachable("unexpected relocation type");
  }
}

// Calculate the value we expect to find at the relocation location.
// This is used as a sanity check before applying a relocation to a given
// location.  It is useful for catching bugs in the compiler and linker.
uint32_t ObjFile::calcExpectedValue(const WasmRelocation &reloc) const {
  switch (reloc.Type) {
  case R_WASM_TABLE_INDEX_I32:
  case R_WASM_TABLE_INDEX_SLEB:
  case R_WASM_TABLE_INDEX_REL_SLEB: {
    const WasmSymbol &sym = wasmObj->syms()[reloc.Index];
    return tableEntries[sym.Info.ElementIndex];
  }
  case R_WASM_MEMORY_ADDR_SLEB:
  case R_WASM_MEMORY_ADDR_I32:
  case R_WASM_MEMORY_ADDR_LEB:
  case R_WASM_MEMORY_ADDR_REL_SLEB: {
    const WasmSymbol &sym = wasmObj->syms()[reloc.Index];
    if (sym.isUndefined())
      return 0;
    const WasmSegment &segment =
        wasmObj->dataSegments()[sym.Info.DataRef.Segment];
    return segment.Data.Offset.Value.Int32 + sym.Info.DataRef.Offset +
           reloc.Addend;
  }
  case R_WASM_FUNCTION_OFFSET_I32: {
    const WasmSymbol &sym = wasmObj->syms()[reloc.Index];
    InputFunction *f =
        functions[sym.Info.ElementIndex - wasmObj->getNumImportedFunctions()];
    return f->getFunctionInputOffset() + f->getFunctionCodeOffset() +
           reloc.Addend;
  }
  case R_WASM_SECTION_OFFSET_I32:
    return reloc.Addend;
  case R_WASM_TYPE_INDEX_LEB:
    return reloc.Index;
  case R_WASM_FUNCTION_INDEX_LEB:
  case R_WASM_GLOBAL_INDEX_LEB:
  case R_WASM_EVENT_INDEX_LEB: {
    const WasmSymbol &sym = wasmObj->syms()[reloc.Index];
    return sym.Info.ElementIndex;
  }
  default:
    llvm_unreachable("unknown relocation type");
  }
}

// Translate from the relocation's index into the final linked output value.
uint32_t ObjFile::calcNewValue(const WasmRelocation &reloc) const {
  const Symbol* sym = nullptr;
  if (reloc.Type != R_WASM_TYPE_INDEX_LEB) {
    sym = symbols[reloc.Index];

    // We can end up with relocations against non-live symbols.  For example
    // in debug sections.
    if ((isa<FunctionSymbol>(sym) || isa<DataSymbol>(sym)) && !sym->isLive())
      return 0;
  }

  switch (reloc.Type) {
  case R_WASM_TABLE_INDEX_I32:
  case R_WASM_TABLE_INDEX_SLEB:
  case R_WASM_TABLE_INDEX_REL_SLEB:
    if (config->isPic && !getFunctionSymbol(reloc.Index)->hasTableIndex())
      return 0;
    return getFunctionSymbol(reloc.Index)->getTableIndex();
  case R_WASM_MEMORY_ADDR_SLEB:
  case R_WASM_MEMORY_ADDR_I32:
  case R_WASM_MEMORY_ADDR_LEB:
  case R_WASM_MEMORY_ADDR_REL_SLEB:
    if (isa<UndefinedData>(sym))
      return 0;
    return cast<DefinedData>(sym)->getVirtualAddress() + reloc.Addend;
  case R_WASM_TYPE_INDEX_LEB:
    return typeMap[reloc.Index];
  case R_WASM_FUNCTION_INDEX_LEB:
    return getFunctionSymbol(reloc.Index)->getFunctionIndex();
  case R_WASM_GLOBAL_INDEX_LEB:
    if (auto gs = dyn_cast<GlobalSymbol>(sym))
      return gs->getGlobalIndex();
    return sym->getGOTIndex();
  case R_WASM_EVENT_INDEX_LEB:
    return getEventSymbol(reloc.Index)->getEventIndex();
  case R_WASM_FUNCTION_OFFSET_I32: {
    auto *f = cast<DefinedFunction>(sym);
    return f->function->outputOffset + f->function->getFunctionCodeOffset() +
           reloc.Addend;
  }
  case R_WASM_SECTION_OFFSET_I32:
    return getSectionSymbol(reloc.Index)->section->outputOffset + reloc.Addend;
  default:
    llvm_unreachable("unknown relocation type");
  }
}

template <class T>
static void setRelocs(const std::vector<T *> &chunks,
                      const WasmSection *section) {
  if (!section)
    return;

  ArrayRef<WasmRelocation> relocs = section->Relocations;
  assert(std::is_sorted(relocs.begin(), relocs.end(),
                        [](const WasmRelocation &r1, const WasmRelocation &r2) {
                          return r1.Offset < r2.Offset;
                        }));
  assert(std::is_sorted(
      chunks.begin(), chunks.end(), [](InputChunk *c1, InputChunk *c2) {
        return c1->getInputSectionOffset() < c2->getInputSectionOffset();
      }));

  auto relocsNext = relocs.begin();
  auto relocsEnd = relocs.end();
  auto relocLess = [](const WasmRelocation &r, uint32_t val) {
    return r.Offset < val;
  };
  for (InputChunk *c : chunks) {
    auto relocsStart = std::lower_bound(relocsNext, relocsEnd,
                                        c->getInputSectionOffset(), relocLess);
    relocsNext = std::lower_bound(
        relocsStart, relocsEnd, c->getInputSectionOffset() + c->getInputSize(),
        relocLess);
    c->setRelocations(ArrayRef<WasmRelocation>(relocsStart, relocsNext));
  }
}

void ObjFile::parse(bool ignoreComdats) {
  // Parse a memory buffer as a wasm file.
  LLVM_DEBUG(dbgs() << "Parsing object: " << toString(this) << "\n");
  std::unique_ptr<Binary> bin = CHECK(createBinary(mb), toString(this));

  auto *obj = dyn_cast<WasmObjectFile>(bin.get());
  if (!obj)
    fatal(toString(this) + ": not a wasm file");
  if (!obj->isRelocatableObject())
    fatal(toString(this) + ": not a relocatable wasm file");

  bin.release();
  wasmObj.reset(obj);

  // Build up a map of function indices to table indices for use when
  // verifying the existing table index relocations
  uint32_t totalFunctions =
      wasmObj->getNumImportedFunctions() + wasmObj->functions().size();
  tableEntries.resize(totalFunctions);
  for (const WasmElemSegment &seg : wasmObj->elements()) {
    if (seg.Offset.Opcode != WASM_OPCODE_I32_CONST)
      fatal(toString(this) + ": invalid table elements");
    uint32_t offset = seg.Offset.Value.Int32;
    for (uint32_t index = 0; index < seg.Functions.size(); index++) {

      uint32_t functionIndex = seg.Functions[index];
      tableEntries[functionIndex] = offset + index;
    }
  }

  uint32_t sectionIndex = 0;

  // Bool for each symbol, true if called directly.  This allows us to implement
  // a weaker form of signature checking where undefined functions that are not
  // called directly (i.e. only address taken) don't have to match the defined
  // function's signature.  We cannot do this for directly called functions
  // because those signatures are checked at validation times.
  // See https://bugs.llvm.org/show_bug.cgi?id=40412
  std::vector<bool> isCalledDirectly(wasmObj->getNumberOfSymbols(), false);
  for (const SectionRef &sec : wasmObj->sections()) {
    const WasmSection &section = wasmObj->getWasmSection(sec);
    // Wasm objects can have at most one code and one data section.
    if (section.Type == WASM_SEC_CODE) {
      assert(!codeSection);
      codeSection = &section;
    } else if (section.Type == WASM_SEC_DATA) {
      assert(!dataSection);
      dataSection = &section;
    } else if (section.Type == WASM_SEC_CUSTOM) {
      customSections.emplace_back(make<InputSection>(section, this));
      customSections.back()->setRelocations(section.Relocations);
      customSectionsByIndex[sectionIndex] = customSections.back();
    }
    sectionIndex++;
    // Scans relocations to dermine determine if a function symbol is called
    // directly
    for (const WasmRelocation &reloc : section.Relocations)
      if (reloc.Type == R_WASM_FUNCTION_INDEX_LEB)
        isCalledDirectly[reloc.Index] = true;
  }

  typeMap.resize(getWasmObj()->types().size());
  typeIsUsed.resize(getWasmObj()->types().size(), false);

  ArrayRef<StringRef> comdats = wasmObj->linkingData().Comdats;
  for (StringRef comdat : comdats) {
    bool isNew = ignoreComdats || symtab->addComdat(comdat);
    keptComdats.push_back(isNew);
  }

  // Populate `Segments`.
  for (const WasmSegment &s : wasmObj->dataSegments()) {
    auto* seg = make<InputSegment>(s, this);
    seg->discarded = isExcludedByComdat(seg);
    segments.emplace_back(seg);
  }
  setRelocs(segments, dataSection);

  // Populate `Functions`.
  ArrayRef<WasmFunction> funcs = wasmObj->functions();
  ArrayRef<uint32_t> funcTypes = wasmObj->functionTypes();
  ArrayRef<WasmSignature> types = wasmObj->types();
  functions.reserve(funcs.size());

  for (size_t i = 0, e = funcs.size(); i != e; ++i) {
    auto* func = make<InputFunction>(types[funcTypes[i]], &funcs[i], this);
    func->discarded = isExcludedByComdat(func);
    functions.emplace_back(func);
  }
  setRelocs(functions, codeSection);

  // Populate `Globals`.
  for (const WasmGlobal &g : wasmObj->globals())
    globals.emplace_back(make<InputGlobal>(g, this));

  // Populate `Events`.
  for (const WasmEvent &e : wasmObj->events())
    events.emplace_back(make<InputEvent>(types[e.Type.SigIndex], e, this));

  // Populate `Symbols` based on the symbols in the object.
  symbols.reserve(wasmObj->getNumberOfSymbols());
  for (const SymbolRef &sym : wasmObj->symbols()) {
    const WasmSymbol &wasmSym = wasmObj->getWasmSymbol(sym.getRawDataRefImpl());
    if (wasmSym.isDefined()) {
      // createDefined may fail if the symbol is comdat excluded in which case
      // we fall back to creating an undefined symbol
      if (Symbol *d = createDefined(wasmSym)) {
        symbols.push_back(d);
        continue;
      }
    }
    size_t idx = symbols.size();
    symbols.push_back(createUndefined(wasmSym, isCalledDirectly[idx]));
  }
}

bool ObjFile::isExcludedByComdat(InputChunk *chunk) const {
  uint32_t c = chunk->getComdat();
  if (c == UINT32_MAX)
    return false;
  return !keptComdats[c];
}

FunctionSymbol *ObjFile::getFunctionSymbol(uint32_t index) const {
  return cast<FunctionSymbol>(symbols[index]);
}

GlobalSymbol *ObjFile::getGlobalSymbol(uint32_t index) const {
  return cast<GlobalSymbol>(symbols[index]);
}

EventSymbol *ObjFile::getEventSymbol(uint32_t index) const {
  return cast<EventSymbol>(symbols[index]);
}

SectionSymbol *ObjFile::getSectionSymbol(uint32_t index) const {
  return cast<SectionSymbol>(symbols[index]);
}

DataSymbol *ObjFile::getDataSymbol(uint32_t index) const {
  return cast<DataSymbol>(symbols[index]);
}

Symbol *ObjFile::createDefined(const WasmSymbol &sym) {
  StringRef name = sym.Info.Name;
  uint32_t flags = sym.Info.Flags;

  switch (sym.Info.Kind) {
  case WASM_SYMBOL_TYPE_FUNCTION: {
    InputFunction *func =
        functions[sym.Info.ElementIndex - wasmObj->getNumImportedFunctions()];
    if (sym.isBindingLocal())
      return make<DefinedFunction>(name, flags, this, func);
    if (func->discarded)
      return nullptr;
    return symtab->addDefinedFunction(name, flags, this, func);
  }
  case WASM_SYMBOL_TYPE_DATA: {
    InputSegment *seg = segments[sym.Info.DataRef.Segment];
    uint32_t offset = sym.Info.DataRef.Offset;
    uint32_t size = sym.Info.DataRef.Size;
    if (sym.isBindingLocal())
      return make<DefinedData>(name, flags, this, seg, offset, size);
    if (seg->discarded)
      return nullptr;
    return symtab->addDefinedData(name, flags, this, seg, offset, size);
  }
  case WASM_SYMBOL_TYPE_GLOBAL: {
    InputGlobal *global =
        globals[sym.Info.ElementIndex - wasmObj->getNumImportedGlobals()];
    if (sym.isBindingLocal())
      return make<DefinedGlobal>(name, flags, this, global);
    return symtab->addDefinedGlobal(name, flags, this, global);
  }
  case WASM_SYMBOL_TYPE_SECTION: {
    InputSection *section = customSectionsByIndex[sym.Info.ElementIndex];
    assert(sym.isBindingLocal());
    return make<SectionSymbol>(flags, section, this);
  }
  case WASM_SYMBOL_TYPE_EVENT: {
    InputEvent *event =
        events[sym.Info.ElementIndex - wasmObj->getNumImportedEvents()];
    if (sym.isBindingLocal())
      return make<DefinedEvent>(name, flags, this, event);
    return symtab->addDefinedEvent(name, flags, this, event);
  }
  }
  llvm_unreachable("unknown symbol kind");
}

Symbol *ObjFile::createUndefined(const WasmSymbol &sym, bool isCalledDirectly) {
  StringRef name = sym.Info.Name;
  uint32_t flags = sym.Info.Flags;

  switch (sym.Info.Kind) {
  case WASM_SYMBOL_TYPE_FUNCTION:
    if (sym.isBindingLocal())
      return make<UndefinedFunction>(name, sym.Info.ImportName,
                                     sym.Info.ImportModule, flags, this,
                                     sym.Signature, isCalledDirectly);
    return symtab->addUndefinedFunction(name, sym.Info.ImportName,
                                        sym.Info.ImportModule, flags, this,
                                        sym.Signature, isCalledDirectly);
  case WASM_SYMBOL_TYPE_DATA:
    if (sym.isBindingLocal())
      return make<UndefinedData>(name, flags, this);
    return symtab->addUndefinedData(name, flags, this);
  case WASM_SYMBOL_TYPE_GLOBAL:
    if (sym.isBindingLocal())
      return make<UndefinedGlobal>(name, sym.Info.ImportName,
                                   sym.Info.ImportModule, flags, this,
                                   sym.GlobalType);
    return symtab->addUndefinedGlobal(name, sym.Info.ImportName,
                                      sym.Info.ImportModule, flags, this,
                                      sym.GlobalType);
  case WASM_SYMBOL_TYPE_SECTION:
    llvm_unreachable("section symbols cannot be undefined");
  }
  llvm_unreachable("unknown symbol kind");
}

void ArchiveFile::parse() {
  // Parse a MemoryBufferRef as an archive file.
  LLVM_DEBUG(dbgs() << "Parsing library: " << toString(this) << "\n");
  file = CHECK(Archive::create(mb), toString(this));

  // Read the symbol table to construct Lazy symbols.
  int count = 0;
  for (const Archive::Symbol &sym : file->symbols()) {
    symtab->addLazy(this, &sym);
    ++count;
  }
  LLVM_DEBUG(dbgs() << "Read " << count << " symbols\n");
}

void ArchiveFile::addMember(const Archive::Symbol *sym) {
  const Archive::Child &c =
      CHECK(sym->getMember(),
            "could not get the member for symbol " + sym->getName());

  // Don't try to load the same member twice (this can happen when members
  // mutually reference each other).
  if (!seen.insert(c.getChildOffset()).second)
    return;

  LLVM_DEBUG(dbgs() << "loading lazy: " << sym->getName() << "\n");
  LLVM_DEBUG(dbgs() << "from archive: " << toString(this) << "\n");

  MemoryBufferRef mb =
      CHECK(c.getMemoryBufferRef(),
            "could not get the buffer for the member defining symbol " +
                sym->getName());

  InputFile *obj = createObjectFile(mb, getName());
  symtab->addFile(obj);
}

static uint8_t mapVisibility(GlobalValue::VisibilityTypes gvVisibility) {
  switch (gvVisibility) {
  case GlobalValue::DefaultVisibility:
    return WASM_SYMBOL_VISIBILITY_DEFAULT;
  case GlobalValue::HiddenVisibility:
  case GlobalValue::ProtectedVisibility:
    return WASM_SYMBOL_VISIBILITY_HIDDEN;
  }
  llvm_unreachable("unknown visibility");
}

static Symbol *createBitcodeSymbol(const std::vector<bool> &keptComdats,
                                   const lto::InputFile::Symbol &objSym,
                                   BitcodeFile &f) {
  StringRef name = saver.save(objSym.getName());

  uint32_t flags = objSym.isWeak() ? WASM_SYMBOL_BINDING_WEAK : 0;
  flags |= mapVisibility(objSym.getVisibility());

  int c = objSym.getComdatIndex();
  bool excludedByComdat = c != -1 && !keptComdats[c];

  if (objSym.isUndefined() || excludedByComdat) {
    if (objSym.isExecutable())
      return symtab->addUndefinedFunction(name, name, defaultModule, flags, &f,
                                          nullptr, true);
    return symtab->addUndefinedData(name, flags, &f);
  }

  if (objSym.isExecutable())
    return symtab->addDefinedFunction(name, flags, &f, nullptr);
  return symtab->addDefinedData(name, flags, &f, nullptr, 0, 0);
}

void BitcodeFile::parse() {
  obj = check(lto::InputFile::create(MemoryBufferRef(
      mb.getBuffer(), saver.save(archiveName + mb.getBufferIdentifier()))));
  Triple t(obj->getTargetTriple());
  if (t.getArch() != Triple::wasm32) {
    error(toString(mb.getBufferIdentifier()) + ": machine type must be wasm32");
    return;
  }
  std::vector<bool> keptComdats;
  for (StringRef s : obj->getComdatTable())
    keptComdats.push_back(symtab->addComdat(s));

  for (const lto::InputFile::Symbol &objSym : obj->symbols())
    symbols.push_back(createBitcodeSymbol(keptComdats, objSym, *this));
}

// Returns a string in the format of "foo.o" or "foo.a(bar.o)".
std::string lld::toString(const wasm::InputFile *file) {
  if (!file)
    return "<internal>";

  if (file->archiveName.empty())
    return file->getName();

  return (file->archiveName + "(" + file->getName() + ")").str();
}
