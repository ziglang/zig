//===- lld/unittest/MachOTests/MachONormalizedFileBinaryWriterTests.cpp ---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "../../lib/ReaderWriter/MachO/MachONormalizedFile.h"
#include "llvm/ADT/Twine.h"
#include "llvm/BinaryFormat/MachO.h"
#include "llvm/Support/FileSystem.h"
#include "gtest/gtest.h"
#include <cassert>
#include <memory>
#include <system_error>
#include <vector>

using llvm::StringRef;
using llvm::MemoryBuffer;
using llvm::SmallString;
using llvm::Twine;
using llvm::ErrorOr;
using namespace llvm::MachO;
using namespace lld::mach_o::normalized;

// Parses binary mach-o file at specified path and returns
// ownership of buffer to mb parameter and ownership of
// Normalized file to nf parameter.
static void fromBinary(StringRef path, std::unique_ptr<MemoryBuffer> &mb,
                       std::unique_ptr<NormalizedFile> &nf, StringRef archStr) {
  ErrorOr<std::unique_ptr<MemoryBuffer>> mbOrErr = MemoryBuffer::getFile(path);
  std::error_code ec = mbOrErr.getError();
  EXPECT_FALSE(ec);
  mb = std::move(mbOrErr.get());

  llvm::Expected<std::unique_ptr<NormalizedFile>> r =
      lld::mach_o::normalized::readBinary(
          mb, lld::MachOLinkingContext::archFromName(archStr));
  EXPECT_FALSE(!r);
  nf.reset(r->release());
}

static Relocation
makeReloc(unsigned addr, bool rel, bool ext, RelocationInfoType type,
                                                              unsigned sym) {
  Relocation result;
  result.offset = addr;
  result.scattered = false;
  result.type = type;
  result.length = 2;
  result.pcRel = rel;
  result.isExtern = ext;
  result.value = 0;
  result.symbol = sym;
  return result;
}

static Relocation
makeScatReloc(unsigned addr, RelocationInfoType type, unsigned value) {
  Relocation result;
  result.offset = addr;
  result.scattered = true;
  result.type = type;
  result.length = 2;
  result.pcRel = false;
  result.isExtern = true;
  result.value = value;
  result.symbol = 0;
  return result;
}

static Symbol
makeUndefSymbol(StringRef name) {
  Symbol sym;
  sym.name = name;
  sym.type = N_UNDF;
  sym.scope = N_EXT;
  sym.sect = NO_SECT;
  sym.desc = 0;
  sym.value = 0;
  return sym;
}


static Symbol
makeSymbol(StringRef name, unsigned addr) {
  Symbol sym;
  sym.name = name;
  sym.type = N_SECT;
  sym.scope = N_EXT;
  sym.sect = 1;
  sym.desc = 0;
  sym.value = addr;
  return sym;
}

static Symbol
makeThumbSymbol(StringRef name, unsigned addr) {
  Symbol sym;
  sym.name = name;
  sym.type = N_SECT;
  sym.scope = N_EXT;
  sym.sect = 1;
  sym.desc = N_ARM_THUMB_DEF;
  sym.value = addr;
  return sym;
}

TEST(BinaryWriterTest, obj_relocs_x86_64) {
  SmallString<128> tmpFl;
  {
    NormalizedFile f;
    f.arch = lld::MachOLinkingContext::arch_x86_64;
    f.fileType = MH_OBJECT;
    f.flags = MH_SUBSECTIONS_VIA_SYMBOLS;
    f.os = lld::MachOLinkingContext::OS::macOSX;
    f.sections.resize(1);
    Section& text = f.sections.front();
    text.segmentName = "__TEXT";
    text.sectionName = "__text";
    text.type = S_REGULAR;
    text.attributes = SectionAttr(S_ATTR_PURE_INSTRUCTIONS
                                      | S_ATTR_SOME_INSTRUCTIONS);
    text.alignment = 16;
    text.address = 0;
    const uint8_t textBytes[] = {
      0xe8, 0x00, 0x00, 0x00, 0x00, 0x48, 0x8b, 0x05,
      0x00, 0x00, 0x00, 0x00, 0xff, 0x35, 0x00, 0x00,
      0x00, 0x00, 0x8b, 0x05, 0x00, 0x00, 0x00, 0x00,
      0xc6, 0x05, 0xff, 0xff, 0xff, 0xff, 0x12, 0xc7,
      0x05, 0xfc, 0xff, 0xff, 0xff, 0x78, 0x56, 0x34,
      0x12, 0x48, 0x8b, 0x3d, 0x00, 0x00, 0x00, 0x00 };

    text.content = llvm::makeArrayRef(textBytes, sizeof(textBytes));
    text.relocations.push_back(makeReloc(0x01, false, true, X86_64_RELOC_BRANCH, 1));
    text.relocations.push_back(makeReloc(0x08, false, true, X86_64_RELOC_GOT_LOAD, 1));
    text.relocations.push_back(makeReloc(0x0E, false, true, X86_64_RELOC_GOT, 1));
    text.relocations.push_back(makeReloc(0x14, false, true, X86_64_RELOC_SIGNED, 1));
    text.relocations.push_back(makeReloc(0x1A, false, true, X86_64_RELOC_SIGNED_1, 1));
    text.relocations.push_back(makeReloc(0x21, false, true, X86_64_RELOC_SIGNED_4, 1));
    text.relocations.push_back(makeReloc(0x2C, false, true, X86_64_RELOC_TLV, 2));

    f.undefinedSymbols.push_back(makeUndefSymbol("_bar"));
    f.undefinedSymbols.push_back(makeUndefSymbol("_tbar"));

    std::error_code ec =
        llvm::sys::fs::createTemporaryFile(Twine("xx"), "o", tmpFl);
    EXPECT_FALSE(ec);
    llvm::Error ec2 = writeBinary(f, tmpFl);
    EXPECT_FALSE(ec2);
  }

  std::unique_ptr<MemoryBuffer> bufferOwner;
  std::unique_ptr<NormalizedFile> f2;
  fromBinary(tmpFl, bufferOwner, f2, "x86_64");

  EXPECT_EQ(lld::MachOLinkingContext::arch_x86_64, f2->arch);
  EXPECT_EQ(MH_OBJECT, f2->fileType);
  EXPECT_EQ(FileFlags(MH_SUBSECTIONS_VIA_SYMBOLS), f2->flags);

  EXPECT_TRUE(f2->localSymbols.empty());
  EXPECT_TRUE(f2->globalSymbols.empty());
  EXPECT_EQ(2UL, f2->undefinedSymbols.size());
  const Symbol& barUndef = f2->undefinedSymbols[0];
  EXPECT_TRUE(barUndef.name.equals("_bar"));
  EXPECT_EQ(N_UNDF, barUndef.type);
  EXPECT_EQ(SymbolScope(N_EXT), barUndef.scope);
  const Symbol& tbarUndef = f2->undefinedSymbols[1];
  EXPECT_TRUE(tbarUndef.name.equals("_tbar"));
  EXPECT_EQ(N_UNDF, tbarUndef.type);
  EXPECT_EQ(SymbolScope(N_EXT), tbarUndef.scope);

  EXPECT_EQ(1UL, f2->sections.size());
  const Section& text = f2->sections[0];
  EXPECT_TRUE(text.segmentName.equals("__TEXT"));
  EXPECT_TRUE(text.sectionName.equals("__text"));
  EXPECT_EQ(S_REGULAR, text.type);
  EXPECT_EQ(text.attributes,SectionAttr(S_ATTR_PURE_INSTRUCTIONS
                                      | S_ATTR_SOME_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)text.alignment, 16U);
  EXPECT_EQ(text.address, Hex64(0x0));
  EXPECT_EQ(48UL, text.content.size());
  const Relocation& call = text.relocations[0];
  EXPECT_EQ(call.offset, Hex32(0x1));
  EXPECT_EQ(call.type, X86_64_RELOC_BRANCH);
  EXPECT_EQ(call.length, 2);
  EXPECT_EQ(call.isExtern, true);
  EXPECT_EQ(call.symbol, 1U);
  const Relocation& gotLoad = text.relocations[1];
  EXPECT_EQ(gotLoad.offset, Hex32(0x8));
  EXPECT_EQ(gotLoad.type, X86_64_RELOC_GOT_LOAD);
  EXPECT_EQ(gotLoad.length, 2);
  EXPECT_EQ(gotLoad.isExtern, true);
  EXPECT_EQ(gotLoad.symbol, 1U);
  const Relocation& gotUse = text.relocations[2];
  EXPECT_EQ(gotUse.offset, Hex32(0xE));
  EXPECT_EQ(gotUse.type, X86_64_RELOC_GOT);
  EXPECT_EQ(gotUse.length, 2);
  EXPECT_EQ(gotUse.isExtern, true);
  EXPECT_EQ(gotUse.symbol, 1U);
  const Relocation& signed0 = text.relocations[3];
  EXPECT_EQ(signed0.offset, Hex32(0x14));
  EXPECT_EQ(signed0.type, X86_64_RELOC_SIGNED);
  EXPECT_EQ(signed0.length, 2);
  EXPECT_EQ(signed0.isExtern, true);
  EXPECT_EQ(signed0.symbol, 1U);
  const Relocation& signed1 = text.relocations[4];
  EXPECT_EQ(signed1.offset, Hex32(0x1A));
  EXPECT_EQ(signed1.type, X86_64_RELOC_SIGNED_1);
  EXPECT_EQ(signed1.length, 2);
  EXPECT_EQ(signed1.isExtern, true);
  EXPECT_EQ(signed1.symbol, 1U);
  const Relocation& signed4 = text.relocations[5];
  EXPECT_EQ(signed4.offset, Hex32(0x21));
  EXPECT_EQ(signed4.type, X86_64_RELOC_SIGNED_4);
  EXPECT_EQ(signed4.length, 2);
  EXPECT_EQ(signed4.isExtern, true);
  EXPECT_EQ(signed4.symbol, 1U);

  bufferOwner.reset(nullptr);
  std::error_code ec = llvm::sys::fs::remove(Twine(tmpFl));
  EXPECT_FALSE(ec);
}



TEST(BinaryWriterTest, obj_relocs_x86) {
  SmallString<128> tmpFl;
  {
    NormalizedFile f;
    f.arch = lld::MachOLinkingContext::arch_x86;
    f.fileType = MH_OBJECT;
    f.flags = MH_SUBSECTIONS_VIA_SYMBOLS;
    f.os = lld::MachOLinkingContext::OS::macOSX;
    f.sections.resize(1);
    Section& text = f.sections.front();
    text.segmentName = "__TEXT";
    text.sectionName = "__text";
    text.type = S_REGULAR;
    text.attributes = SectionAttr(S_ATTR_PURE_INSTRUCTIONS
                                      | S_ATTR_SOME_INSTRUCTIONS);
    text.alignment = 16;
    text.address = 0;
    const uint8_t textBytes[] = {
       0xe8, 0xfb, 0xff, 0xff, 0xff, 0xa1, 0x00, 0x00,
       0x00, 0x00, 0x8b, 0xb0, 0xfb, 0xff, 0xff, 0xff,
       0x8b, 0x80, 0x11, 0x00, 0x00, 0x00 };

    text.content = llvm::makeArrayRef(textBytes, sizeof(textBytes));
    text.relocations.push_back(makeReloc(0x01, true, true, GENERIC_RELOC_VANILLA, 0));
    text.relocations.push_back(makeReloc(0x06, false, true, GENERIC_RELOC_VANILLA, 0));
    text.relocations.push_back(makeScatReloc(0x0c, GENERIC_RELOC_LOCAL_SECTDIFF, 0));
    text.relocations.push_back(makeScatReloc(0x0, GENERIC_RELOC_PAIR, 5));
    text.relocations.push_back(makeReloc(0x12, true, true, GENERIC_RELOC_TLV, 1));

    f.undefinedSymbols.push_back(makeUndefSymbol("_bar"));
    f.undefinedSymbols.push_back(makeUndefSymbol("_tbar"));

    std::error_code ec =
        llvm::sys::fs::createTemporaryFile(Twine("xx"), "o", tmpFl);
    EXPECT_FALSE(ec);
    llvm::Error ec2 = writeBinary(f, tmpFl);
    EXPECT_FALSE(ec2);
  }
  std::unique_ptr<MemoryBuffer> bufferOwner;
  std::unique_ptr<NormalizedFile> f2;
  fromBinary(tmpFl, bufferOwner, f2, "i386");

  EXPECT_EQ(lld::MachOLinkingContext::arch_x86, f2->arch);
  EXPECT_EQ(MH_OBJECT, f2->fileType);
  EXPECT_EQ(FileFlags(MH_SUBSECTIONS_VIA_SYMBOLS), f2->flags);

  EXPECT_TRUE(f2->localSymbols.empty());
  EXPECT_TRUE(f2->globalSymbols.empty());
  EXPECT_EQ(2UL, f2->undefinedSymbols.size());
  const Symbol& barUndef = f2->undefinedSymbols[0];
  EXPECT_TRUE(barUndef.name.equals("_bar"));
  EXPECT_EQ(N_UNDF, barUndef.type);
  EXPECT_EQ(SymbolScope(N_EXT), barUndef.scope);
  const Symbol& tbarUndef = f2->undefinedSymbols[1];
  EXPECT_TRUE(tbarUndef.name.equals("_tbar"));
  EXPECT_EQ(N_UNDF, tbarUndef.type);
  EXPECT_EQ(SymbolScope(N_EXT), tbarUndef.scope);

  EXPECT_EQ(1UL, f2->sections.size());
  const Section& text = f2->sections[0];
  EXPECT_TRUE(text.segmentName.equals("__TEXT"));
  EXPECT_TRUE(text.sectionName.equals("__text"));
  EXPECT_EQ(S_REGULAR, text.type);
  EXPECT_EQ(text.attributes,SectionAttr(S_ATTR_PURE_INSTRUCTIONS
                                      | S_ATTR_SOME_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)text.alignment, 16U);
  EXPECT_EQ(text.address, Hex64(0x0));
  EXPECT_EQ(22UL, text.content.size());
  const Relocation& call = text.relocations[0];
  EXPECT_EQ(call.offset, Hex32(0x1));
  EXPECT_EQ(call.scattered, false);
  EXPECT_EQ(call.type, GENERIC_RELOC_VANILLA);
  EXPECT_EQ(call.pcRel, true);
  EXPECT_EQ(call.length, 2);
  EXPECT_EQ(call.isExtern, true);
  EXPECT_EQ(call.symbol, 0U);
  const Relocation& absLoad = text.relocations[1];
  EXPECT_EQ(absLoad.offset, Hex32(0x6));
  EXPECT_EQ(absLoad.scattered, false);
  EXPECT_EQ(absLoad.type, GENERIC_RELOC_VANILLA);
  EXPECT_EQ(absLoad.pcRel, false);
  EXPECT_EQ(absLoad.length, 2);
  EXPECT_EQ(absLoad.isExtern, true);
  EXPECT_EQ(absLoad.symbol,0U);
  const Relocation& pic1 = text.relocations[2];
  EXPECT_EQ(pic1.offset, Hex32(0xc));
  EXPECT_EQ(pic1.scattered, true);
  EXPECT_EQ(pic1.type, GENERIC_RELOC_LOCAL_SECTDIFF);
  EXPECT_EQ(pic1.length, 2);
  EXPECT_EQ(pic1.value, 0U);
  const Relocation& pic2 = text.relocations[3];
  EXPECT_EQ(pic2.offset, Hex32(0x0));
  EXPECT_EQ(pic1.scattered, true);
  EXPECT_EQ(pic2.type, GENERIC_RELOC_PAIR);
  EXPECT_EQ(pic2.length, 2);
  EXPECT_EQ(pic2.value, 5U);
  const Relocation& tlv = text.relocations[4];
  EXPECT_EQ(tlv.offset, Hex32(0x12));
  EXPECT_EQ(tlv.type, GENERIC_RELOC_TLV);
  EXPECT_EQ(tlv.length, 2);
  EXPECT_EQ(tlv.isExtern, true);
  EXPECT_EQ(tlv.symbol, 1U);

  //llvm::errs() << "temp = " << tmpFl << "\n";
  bufferOwner.reset(nullptr);
  std::error_code ec = llvm::sys::fs::remove(Twine(tmpFl));
  EXPECT_FALSE(ec);
}



TEST(BinaryWriterTest, obj_relocs_armv7) {
  SmallString<128> tmpFl;
  {
    NormalizedFile f;
    f.arch = lld::MachOLinkingContext::arch_armv7;
    f.fileType = MH_OBJECT;
    f.flags = MH_SUBSECTIONS_VIA_SYMBOLS;
    f.os = lld::MachOLinkingContext::OS::macOSX;
    f.sections.resize(1);
    Section& text = f.sections.front();
    text.segmentName = "__TEXT";
    text.sectionName = "__text";
    text.type = S_REGULAR;
    text.attributes = SectionAttr(S_ATTR_PURE_INSTRUCTIONS
                                      | S_ATTR_SOME_INSTRUCTIONS);
    text.alignment = 4;
    text.address = 0;
    const uint8_t textBytes[] = {
      0xff, 0xf7, 0xfe, 0xef, 0x40, 0xf2, 0x05, 0x01,
      0xc0, 0xf2, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00,
      0x00, 0xbf };

    text.content = llvm::makeArrayRef(textBytes, sizeof(textBytes));
    text.relocations.push_back(makeReloc(0x00, true, true,
                                        ARM_THUMB_RELOC_BR22, 2));
    text.relocations.push_back(makeScatReloc(0x04,
                                        ARM_RELOC_HALF_SECTDIFF, 0x10));
    text.relocations.push_back(makeScatReloc(0x00,
                                        ARM_RELOC_PAIR, 0xC));
    text.relocations.push_back(makeScatReloc(0x08,
                                        ARM_RELOC_HALF_SECTDIFF, 0x10));
    text.relocations.push_back(makeScatReloc(0x00,
                                        ARM_RELOC_PAIR, 0xC));
    text.relocations.push_back(makeReloc(0x0C, false, true,
                                        ARM_RELOC_VANILLA, 2));

    f.globalSymbols.push_back(makeThumbSymbol("_foo", 0x00));
    f.globalSymbols.push_back(makeThumbSymbol("_foo2", 0x10));
    f.undefinedSymbols.push_back(makeUndefSymbol("_bar"));

    std::error_code ec =
        llvm::sys::fs::createTemporaryFile(Twine("xx"), "o", tmpFl);
    EXPECT_FALSE(ec);
    llvm::Error ec2 = writeBinary(f, tmpFl);
    EXPECT_FALSE(ec2);
  }
  std::unique_ptr<MemoryBuffer> bufferOwner;
  std::unique_ptr<NormalizedFile> f2;
  fromBinary(tmpFl, bufferOwner, f2, "armv7");

  EXPECT_EQ(lld::MachOLinkingContext::arch_armv7, f2->arch);
  EXPECT_EQ(MH_OBJECT, f2->fileType);
  EXPECT_EQ(FileFlags(MH_SUBSECTIONS_VIA_SYMBOLS), f2->flags);

  EXPECT_TRUE(f2->localSymbols.empty());
  EXPECT_EQ(2UL, f2->globalSymbols.size());
  const Symbol& fooDef = f2->globalSymbols[0];
  EXPECT_TRUE(fooDef.name.equals("_foo"));
  EXPECT_EQ(N_SECT, fooDef.type);
  EXPECT_EQ(1, fooDef.sect);
  EXPECT_EQ(SymbolScope(N_EXT), fooDef.scope);
  const Symbol& foo2Def = f2->globalSymbols[1];
  EXPECT_TRUE(foo2Def.name.equals("_foo2"));
  EXPECT_EQ(N_SECT, foo2Def.type);
  EXPECT_EQ(1, foo2Def.sect);
  EXPECT_EQ(SymbolScope(N_EXT), foo2Def.scope);

  EXPECT_EQ(1UL, f2->undefinedSymbols.size());
  const Symbol& barUndef = f2->undefinedSymbols[0];
  EXPECT_TRUE(barUndef.name.equals("_bar"));
  EXPECT_EQ(N_UNDF, barUndef.type);
  EXPECT_EQ(SymbolScope(N_EXT), barUndef.scope);

  EXPECT_EQ(1UL, f2->sections.size());
  const Section& text = f2->sections[0];
  EXPECT_TRUE(text.segmentName.equals("__TEXT"));
  EXPECT_TRUE(text.sectionName.equals("__text"));
  EXPECT_EQ(S_REGULAR, text.type);
  EXPECT_EQ(text.attributes,SectionAttr(S_ATTR_PURE_INSTRUCTIONS
                                      | S_ATTR_SOME_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)text.alignment, 4U);
  EXPECT_EQ(text.address, Hex64(0x0));
  EXPECT_EQ(18UL, text.content.size());
  const Relocation& blx = text.relocations[0];
  EXPECT_EQ(blx.offset, Hex32(0x0));
  EXPECT_EQ(blx.scattered, false);
  EXPECT_EQ(blx.type, ARM_THUMB_RELOC_BR22);
  EXPECT_EQ(blx.pcRel, true);
  EXPECT_EQ(blx.length, 2);
  EXPECT_EQ(blx.isExtern, true);
  EXPECT_EQ(blx.symbol, 2U);
  const Relocation& movw1 = text.relocations[1];
  EXPECT_EQ(movw1.offset, Hex32(0x4));
  EXPECT_EQ(movw1.scattered, true);
  EXPECT_EQ(movw1.type, ARM_RELOC_HALF_SECTDIFF);
  EXPECT_EQ(movw1.length, 2);
  EXPECT_EQ(movw1.value, 0x10U);
  const Relocation& movw2 = text.relocations[2];
  EXPECT_EQ(movw2.offset, Hex32(0x0));
  EXPECT_EQ(movw2.scattered, true);
  EXPECT_EQ(movw2.type, ARM_RELOC_PAIR);
  EXPECT_EQ(movw2.length, 2);
  EXPECT_EQ(movw2.value, Hex32(0xC));
   const Relocation& movt1 = text.relocations[3];
  EXPECT_EQ(movt1.offset, Hex32(0x8));
  EXPECT_EQ(movt1.scattered, true);
  EXPECT_EQ(movt1.type, ARM_RELOC_HALF_SECTDIFF);
  EXPECT_EQ(movt1.length, 2);
  EXPECT_EQ(movt1.value, Hex32(0x10));
  const Relocation& movt2 = text.relocations[4];
  EXPECT_EQ(movt2.offset, Hex32(0x0));
  EXPECT_EQ(movt2.scattered, true);
  EXPECT_EQ(movt2.type, ARM_RELOC_PAIR);
  EXPECT_EQ(movt2.length, 2);
  EXPECT_EQ(movt2.value, Hex32(0xC));
 const Relocation& absPointer = text.relocations[5];
  EXPECT_EQ(absPointer.offset, Hex32(0xC));
  EXPECT_EQ(absPointer.type, ARM_RELOC_VANILLA);
  EXPECT_EQ(absPointer.length, 2);
  EXPECT_EQ(absPointer.isExtern, true);
  EXPECT_EQ(absPointer.symbol, 2U);

  //llvm::errs() << "temp = " << tmpFl << "\n";
  bufferOwner.reset(nullptr);
  std::error_code ec = llvm::sys::fs::remove(Twine(tmpFl));
  EXPECT_FALSE(ec);
}



TEST(BinaryWriterTest, obj_relocs_ppc) {
  SmallString<128> tmpFl;
  {
    NormalizedFile f;
    f.arch = lld::MachOLinkingContext::arch_ppc;
    f.fileType = MH_OBJECT;
    f.flags = MH_SUBSECTIONS_VIA_SYMBOLS;
    f.os = lld::MachOLinkingContext::OS::macOSX;
    f.sections.resize(1);
    Section& text = f.sections.front();
    text.segmentName = "__TEXT";
    text.sectionName = "__text";
    text.type = S_REGULAR;
    text.attributes = SectionAttr(S_ATTR_PURE_INSTRUCTIONS
                                      | S_ATTR_SOME_INSTRUCTIONS);
    text.alignment = 4;
    text.address = 0;
    const uint8_t textBytes[] = {
      0x48, 0x00, 0x00, 0x01, 0x40, 0x82, 0xff, 0xfc,
      0x3c, 0x62, 0x00, 0x00, 0x3c, 0x62, 0x00, 0x00,
      0x80, 0x63, 0x00, 0x24, 0x80, 0x63, 0x00, 0x24,
      0x3c, 0x40, 0x00, 0x00, 0x3c, 0x60, 0x00, 0x00,
      0x80, 0x42, 0x00, 0x28, 0x80, 0x63, 0x00, 0x28,
      0x60, 0x00, 0x00, 0x00 };

    text.content = llvm::makeArrayRef(textBytes, sizeof(textBytes));
    text.relocations.push_back(makeReloc(0x00, true, true,
                                        PPC_RELOC_BR24, 2));
    text.relocations.push_back(makeReloc(0x04, true, true,
                                        PPC_RELOC_BR14, 2));
    text.relocations.push_back(makeScatReloc(0x08,
                                        PPC_RELOC_HI16_SECTDIFF, 0x28));
    text.relocations.push_back(makeScatReloc(0x24,
                                        PPC_RELOC_PAIR, 0x4));
    text.relocations.push_back(makeScatReloc(0x0C,
                                        PPC_RELOC_HA16_SECTDIFF, 0x28));
    text.relocations.push_back(makeScatReloc(0x24,
                                        PPC_RELOC_PAIR, 0x4));
    text.relocations.push_back(makeScatReloc(0x10,
                                        PPC_RELOC_LO16_SECTDIFF, 0x28));
    text.relocations.push_back(makeScatReloc(0x00,
                                        PPC_RELOC_PAIR, 0x4));
    text.relocations.push_back(makeScatReloc(0x14,
                                        PPC_RELOC_LO14_SECTDIFF, 0x28));
    text.relocations.push_back(makeScatReloc(0x00,
                                        PPC_RELOC_PAIR, 0x4));
    text.relocations.push_back(makeReloc(0x18, false, false,
                                        PPC_RELOC_HI16, 1));
    text.relocations.push_back(makeReloc(0x28, false, false,
                                        PPC_RELOC_PAIR, 0));
    text.relocations.push_back(makeReloc(0x1C, false, false,
                                        PPC_RELOC_HA16, 1));
    text.relocations.push_back(makeReloc(0x28, false, false,
                                        PPC_RELOC_PAIR, 0));
    text.relocations.push_back(makeReloc(0x20, false, false,
                                        PPC_RELOC_LO16, 1));
    text.relocations.push_back(makeReloc(0x00, false, false,
                                        PPC_RELOC_PAIR, 0));
    text.relocations.push_back(makeReloc(0x24, false, false,
                                        PPC_RELOC_LO14, 1));
    text.relocations.push_back(makeReloc(0x00, false, false,
                                        PPC_RELOC_PAIR, 0));

    f.globalSymbols.push_back(makeSymbol("_foo", 0x00));
    f.globalSymbols.push_back(makeSymbol("_foo2", 0x28));
    f.undefinedSymbols.push_back(makeUndefSymbol("_bar"));

    std::error_code ec =
        llvm::sys::fs::createTemporaryFile(Twine("xx"), "o", tmpFl);
    EXPECT_FALSE(ec);
    llvm::Error ec2 = writeBinary(f, tmpFl);
    EXPECT_FALSE(ec2);
  }
  std::unique_ptr<MemoryBuffer> bufferOwner;
  std::unique_ptr<NormalizedFile> f2;
  fromBinary(tmpFl, bufferOwner, f2, "ppc");

  EXPECT_EQ(lld::MachOLinkingContext::arch_ppc, f2->arch);
  EXPECT_EQ(MH_OBJECT, f2->fileType);
  EXPECT_EQ(FileFlags(MH_SUBSECTIONS_VIA_SYMBOLS), f2->flags);

  EXPECT_TRUE(f2->localSymbols.empty());
  EXPECT_EQ(2UL, f2->globalSymbols.size());
  const Symbol& fooDef = f2->globalSymbols[0];
  EXPECT_TRUE(fooDef.name.equals("_foo"));
  EXPECT_EQ(N_SECT, fooDef.type);
  EXPECT_EQ(1, fooDef.sect);
  EXPECT_EQ(SymbolScope(N_EXT), fooDef.scope);
  const Symbol& foo2Def = f2->globalSymbols[1];
  EXPECT_TRUE(foo2Def.name.equals("_foo2"));
  EXPECT_EQ(N_SECT, foo2Def.type);
  EXPECT_EQ(1, foo2Def.sect);
  EXPECT_EQ(SymbolScope(N_EXT), foo2Def.scope);

  EXPECT_EQ(1UL, f2->undefinedSymbols.size());
  const Symbol& barUndef = f2->undefinedSymbols[0];
  EXPECT_TRUE(barUndef.name.equals("_bar"));
  EXPECT_EQ(N_UNDF, barUndef.type);
  EXPECT_EQ(SymbolScope(N_EXT), barUndef.scope);

  EXPECT_EQ(1UL, f2->sections.size());
  const Section& text = f2->sections[0];
  EXPECT_TRUE(text.segmentName.equals("__TEXT"));
  EXPECT_TRUE(text.sectionName.equals("__text"));
  EXPECT_EQ(S_REGULAR, text.type);
  EXPECT_EQ(text.attributes,SectionAttr(S_ATTR_PURE_INSTRUCTIONS
                                      | S_ATTR_SOME_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)text.alignment, 4U);
  EXPECT_EQ(text.address, Hex64(0x0));
  EXPECT_EQ(44UL, text.content.size());
  const Relocation& br24 = text.relocations[0];
  EXPECT_EQ(br24.offset, Hex32(0x0));
  EXPECT_EQ(br24.scattered, false);
  EXPECT_EQ(br24.type, PPC_RELOC_BR24);
  EXPECT_EQ(br24.pcRel, true);
  EXPECT_EQ(br24.length, 2);
  EXPECT_EQ(br24.isExtern, true);
  EXPECT_EQ(br24.symbol, 2U);
  const Relocation& br14 = text.relocations[1];
  EXPECT_EQ(br14.offset, Hex32(0x4));
  EXPECT_EQ(br14.scattered, false);
  EXPECT_EQ(br14.type, PPC_RELOC_BR14);
  EXPECT_EQ(br14.pcRel, true);
  EXPECT_EQ(br14.length, 2);
  EXPECT_EQ(br14.isExtern, true);
  EXPECT_EQ(br14.symbol, 2U);
  const Relocation& pichi1 = text.relocations[2];
  EXPECT_EQ(pichi1.offset, Hex32(0x8));
  EXPECT_EQ(pichi1.scattered, true);
  EXPECT_EQ(pichi1.type, PPC_RELOC_HI16_SECTDIFF);
  EXPECT_EQ(pichi1.length, 2);
  EXPECT_EQ(pichi1.value, 0x28U);
  const Relocation& pichi2 = text.relocations[3];
  EXPECT_EQ(pichi2.offset, Hex32(0x24));
  EXPECT_EQ(pichi2.scattered, true);
  EXPECT_EQ(pichi2.type, PPC_RELOC_PAIR);
  EXPECT_EQ(pichi2.length, 2);
  EXPECT_EQ(pichi2.value, 0x4U);
  const Relocation& picha1 = text.relocations[4];
  EXPECT_EQ(picha1.offset, Hex32(0xC));
  EXPECT_EQ(picha1.scattered, true);
  EXPECT_EQ(picha1.type, PPC_RELOC_HA16_SECTDIFF);
  EXPECT_EQ(picha1.length, 2);
  EXPECT_EQ(picha1.value, 0x28U);
  const Relocation& picha2 = text.relocations[5];
  EXPECT_EQ(picha2.offset, Hex32(0x24));
  EXPECT_EQ(picha2.scattered, true);
  EXPECT_EQ(picha2.type, PPC_RELOC_PAIR);
  EXPECT_EQ(picha2.length, 2);
  EXPECT_EQ(picha2.value, 0x4U);
  const Relocation& piclo1 = text.relocations[6];
  EXPECT_EQ(piclo1.offset, Hex32(0x10));
  EXPECT_EQ(piclo1.scattered, true);
  EXPECT_EQ(piclo1.type, PPC_RELOC_LO16_SECTDIFF);
  EXPECT_EQ(piclo1.length, 2);
  EXPECT_EQ(piclo1.value, 0x28U);
  const Relocation& piclo2 = text.relocations[7];
  EXPECT_EQ(piclo2.offset, Hex32(0x0));
  EXPECT_EQ(piclo2.scattered, true);
  EXPECT_EQ(piclo2.type, PPC_RELOC_PAIR);
  EXPECT_EQ(piclo2.length, 2);
  EXPECT_EQ(piclo2.value, 0x4U);
  const Relocation& picloa1 = text.relocations[8];
  EXPECT_EQ(picloa1.offset, Hex32(0x14));
  EXPECT_EQ(picloa1.scattered, true);
  EXPECT_EQ(picloa1.type, PPC_RELOC_LO14_SECTDIFF);
  EXPECT_EQ(picloa1.length, 2);
  EXPECT_EQ(picloa1.value, 0x28U);
  const Relocation& picloa2 = text.relocations[9];
  EXPECT_EQ(picloa2.offset, Hex32(0x0));
  EXPECT_EQ(picloa2.scattered, true);
  EXPECT_EQ(picloa2.type, PPC_RELOC_PAIR);
  EXPECT_EQ(picloa2.length, 2);
  EXPECT_EQ(picloa2.value, 0x4U);
  const Relocation& abshi1 = text.relocations[10];
  EXPECT_EQ(abshi1.offset, Hex32(0x18));
  EXPECT_EQ(abshi1.scattered, false);
  EXPECT_EQ(abshi1.type, PPC_RELOC_HI16);
  EXPECT_EQ(abshi1.length, 2);
  EXPECT_EQ(abshi1.symbol, 1U);
  const Relocation& abshi2 = text.relocations[11];
  EXPECT_EQ(abshi2.offset, Hex32(0x28));
  EXPECT_EQ(abshi2.scattered, false);
  EXPECT_EQ(abshi2.type, PPC_RELOC_PAIR);
  EXPECT_EQ(abshi2.length, 2);
  EXPECT_EQ(abshi2.symbol, 0U);
  const Relocation& absha1 = text.relocations[12];
  EXPECT_EQ(absha1.offset, Hex32(0x1C));
  EXPECT_EQ(absha1.scattered, false);
  EXPECT_EQ(absha1.type, PPC_RELOC_HA16);
  EXPECT_EQ(absha1.length, 2);
  EXPECT_EQ(absha1.symbol, 1U);
  const Relocation& absha2 = text.relocations[13];
  EXPECT_EQ(absha2.offset, Hex32(0x28));
  EXPECT_EQ(absha2.scattered, false);
  EXPECT_EQ(absha2.type, PPC_RELOC_PAIR);
  EXPECT_EQ(absha2.length, 2);
  EXPECT_EQ(absha2.symbol, 0U);
  const Relocation& abslo1 = text.relocations[14];
  EXPECT_EQ(abslo1.offset, Hex32(0x20));
  EXPECT_EQ(abslo1.scattered, false);
  EXPECT_EQ(abslo1.type, PPC_RELOC_LO16);
  EXPECT_EQ(abslo1.length, 2);
  EXPECT_EQ(abslo1.symbol, 1U);
  const Relocation& abslo2 = text.relocations[15];
  EXPECT_EQ(abslo2.offset, Hex32(0x00));
  EXPECT_EQ(abslo2.scattered, false);
  EXPECT_EQ(abslo2.type, PPC_RELOC_PAIR);
  EXPECT_EQ(abslo2.length, 2);
  EXPECT_EQ(abslo2.symbol, 0U);
  const Relocation& absloa1 = text.relocations[16];
  EXPECT_EQ(absloa1.offset, Hex32(0x24));
  EXPECT_EQ(absloa1.scattered, false);
  EXPECT_EQ(absloa1.type, PPC_RELOC_LO14);
  EXPECT_EQ(absloa1.length, 2);
  EXPECT_EQ(absloa1.symbol, 1U);
  const Relocation& absloa2 = text.relocations[17];
  EXPECT_EQ(absloa2.offset, Hex32(0x00));
  EXPECT_EQ(absloa2.scattered, false);
  EXPECT_EQ(absloa2.type, PPC_RELOC_PAIR);
  EXPECT_EQ(absloa2.length, 2);
  EXPECT_EQ(absloa2.symbol, 0U);

  bufferOwner.reset(nullptr);
  std::error_code ec = llvm::sys::fs::remove(Twine(tmpFl));
  EXPECT_FALSE(ec);
}
