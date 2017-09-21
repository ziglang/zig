//===- lld/unittest/MachOTests/MachONormalizedFileYAMLTests.cpp -----------===//
//
//                     The LLVM Compiler Infrastructure
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#include "../../lib/ReaderWriter/MachO/MachONormalizedFile.h"
#include "lld/ReaderWriter/MachOLinkingContext.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/BinaryFormat/MachO.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/raw_ostream.h"
#include "gtest/gtest.h"
#include <cstdint>
#include <memory>
#include <string>
#include <system_error>

using llvm::StringRef;
using llvm::MemoryBuffer;
using lld::mach_o::normalized::NormalizedFile;
using lld::mach_o::normalized::Symbol;
using lld::mach_o::normalized::Section;
using lld::mach_o::normalized::Relocation;

static std::unique_ptr<NormalizedFile> fromYAML(StringRef str) {
  std::unique_ptr<MemoryBuffer> mb(MemoryBuffer::getMemBuffer(str));
  llvm::Expected<std::unique_ptr<NormalizedFile>> r
                                    = lld::mach_o::normalized::readYaml(mb);
  EXPECT_FALSE(!r);
  return std::move(*r);
}

static void toYAML(const NormalizedFile &f, std::string &out) {
  llvm::raw_string_ostream ostr(out);
  std::error_code ec = lld::mach_o::normalized::writeYaml(f, ostr);
  EXPECT_TRUE(!ec);
}

// ppc is no longer supported, but it is here to test endianness handling.
TEST(ObjectFileYAML, empty_ppc) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      ppc\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_ppc);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_TRUE(f->sections.empty());
  EXPECT_TRUE(f->localSymbols.empty());
  EXPECT_TRUE(f->globalSymbols.empty());
  EXPECT_TRUE(f->undefinedSymbols.empty());
}

TEST(ObjectFileYAML, empty_x86_64) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      x86_64\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_x86_64);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_TRUE(f->sections.empty());
  EXPECT_TRUE(f->localSymbols.empty());
  EXPECT_TRUE(f->globalSymbols.empty());
  EXPECT_TRUE(f->undefinedSymbols.empty());
}

TEST(ObjectFileYAML, empty_x86) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      x86\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_x86);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_TRUE(f->sections.empty());
  EXPECT_TRUE(f->localSymbols.empty());
  EXPECT_TRUE(f->globalSymbols.empty());
  EXPECT_TRUE(f->undefinedSymbols.empty());
}

TEST(ObjectFileYAML, empty_armv6) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      armv6\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_armv6);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_TRUE(f->sections.empty());
  EXPECT_TRUE(f->localSymbols.empty());
  EXPECT_TRUE(f->globalSymbols.empty());
  EXPECT_TRUE(f->undefinedSymbols.empty());
}

TEST(ObjectFileYAML, empty_armv7) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      armv7\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_armv7);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_TRUE(f->sections.empty());
  EXPECT_TRUE(f->localSymbols.empty());
  EXPECT_TRUE(f->globalSymbols.empty());
  EXPECT_TRUE(f->undefinedSymbols.empty());
}

TEST(ObjectFileYAML, empty_armv7s) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      armv7s\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_armv7s);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_TRUE(f->sections.empty());
  EXPECT_TRUE(f->localSymbols.empty());
  EXPECT_TRUE(f->globalSymbols.empty());
  EXPECT_TRUE(f->undefinedSymbols.empty());
}

TEST(ObjectFileYAML, roundTrip) {
  std::string intermediate;
  {
    NormalizedFile f;
    f.arch = lld::MachOLinkingContext::arch_x86_64;
    f.fileType = llvm::MachO::MH_OBJECT;
    f.flags = llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS;
    f.os = lld::MachOLinkingContext::OS::macOSX;
    toYAML(f, intermediate);
  }
  {
    std::unique_ptr<NormalizedFile> f2 = fromYAML(intermediate);
    EXPECT_EQ(f2->arch, lld::MachOLinkingContext::arch_x86_64);
    EXPECT_EQ((int)(f2->fileType), llvm::MachO::MH_OBJECT);
    EXPECT_EQ((int)(f2->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
    EXPECT_TRUE(f2->sections.empty());
    EXPECT_TRUE(f2->localSymbols.empty());
    EXPECT_TRUE(f2->globalSymbols.empty());
    EXPECT_TRUE(f2->undefinedSymbols.empty());
  }
}

TEST(ObjectFileYAML, oneSymbol) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      x86_64\n"
    "file-type: MH_OBJECT\n"
    "global-symbols:\n"
    "  - name:   _main\n"
    "    type:   N_SECT\n"
    "    scope:  [ N_EXT ]\n"
    "    sect:   1\n"
    "    desc:   [ ]\n"
    "    value:  0x100\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_x86_64);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_TRUE(f->sections.empty());
  EXPECT_TRUE(f->localSymbols.empty());
  EXPECT_TRUE(f->undefinedSymbols.empty());
  EXPECT_EQ(f->globalSymbols.size(), 1UL);
  const Symbol& sym = f->globalSymbols[0];
  EXPECT_TRUE(sym.name.equals("_main"));
  EXPECT_EQ((int)(sym.type), llvm::MachO::N_SECT);
  EXPECT_EQ((int)(sym.scope), llvm::MachO::N_EXT);
  EXPECT_EQ(sym.sect, 1);
  EXPECT_EQ((int)(sym.desc), 0);
  EXPECT_EQ((uint64_t)sym.value, 0x100ULL);
}

TEST(ObjectFileYAML, oneSection) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      x86_64\n"
    "file-type: MH_OBJECT\n"
    "sections:\n"
    "  - segment:     __TEXT\n"
    "    section:     __text\n"
    "    type:        S_REGULAR\n"
    "    attributes:  [ S_ATTR_PURE_INSTRUCTIONS ]\n"
    "    alignment:   2\n"
    "    address:     0x12345678\n"
    "    content:     [ 0x90, 0x90 ]\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_x86_64);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_TRUE(f->localSymbols.empty());
  EXPECT_TRUE(f->globalSymbols.empty());
  EXPECT_TRUE(f->undefinedSymbols.empty());
  EXPECT_EQ(f->sections.size(), 1UL);
  const Section& sect = f->sections[0];
  EXPECT_TRUE(sect.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect.sectionName.equals("__text"));
  EXPECT_EQ((uint32_t)(sect.type), (uint32_t)(llvm::MachO::S_REGULAR));
  EXPECT_EQ((uint32_t)(sect.attributes),
                            (uint32_t)(llvm::MachO::S_ATTR_PURE_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)sect.alignment, 2U);
  EXPECT_EQ((uint64_t)sect.address, 0x12345678ULL);
  EXPECT_EQ(sect.content.size(), 2UL);
  EXPECT_EQ((int)(sect.content[0]), 0x90);
  EXPECT_EQ((int)(sect.content[1]), 0x90);
}

TEST(ObjectFileYAML, hello_x86_64) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      x86_64\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "sections:\n"
    "  - segment:     __TEXT\n"
    "    section:     __text\n"
    "    type:        S_REGULAR\n"
    "    attributes:  [ S_ATTR_PURE_INSTRUCTIONS, S_ATTR_SOME_INSTRUCTIONS]\n"
    "    alignment:   1\n"
    "    address:     0x0000\n"
    "    content:     [ 0x55, 0x48, 0x89, 0xe5, 0x48, 0x8d, 0x3d, 0x00,\n"
    "                   0x00, 0x00, 0x00, 0x30, 0xc0, 0xe8, 0x00, 0x00,\n"
    "                   0x00, 0x00, 0x31, 0xc0, 0x5d, 0xc3 ]\n"
    "    relocations:\n"
    "     - offset:     0x0e\n"
    "       type:       X86_64_RELOC_BRANCH\n"
    "       length:     2\n"
    "       pc-rel:     true\n"
    "       extern:     true\n"
    "       symbol:     2\n"
    "     - offset:     0x07\n"
    "       type:       X86_64_RELOC_SIGNED\n"
    "       length:     2\n"
    "       pc-rel:     true\n"
    "       extern:     true\n"
    "       symbol:     1\n"
    "  - segment:     __TEXT\n"
    "    section:     __cstring\n"
    "    type:        S_CSTRING_LITERALS\n"
    "    attributes:  [ ]\n"
    "    alignment:   1\n"
    "    address:     0x0016\n"
    "    content:     [ 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x0a, 0x00 ]\n"
    "global-symbols:\n"
    "  - name:   _main\n"
    "    type:   N_SECT\n"
    "    scope:  [ N_EXT ]\n"
    "    sect:   1\n"
    "    value:  0x0\n"
    "local-symbols:\n"
    "  - name:   L_.str\n"
    "    type:   N_SECT\n"
    "    scope:  [ ]\n"
    "    sect:   2\n"
    "    value:  0x16\n"
    "undefined-symbols:\n"
    "  - name:   _printf\n"
    "    type:   N_UNDF\n"
    "    value:  0x0\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_x86_64);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_EQ(f->sections.size(), 2UL);

  const Section& sect1 = f->sections[0];
  EXPECT_TRUE(sect1.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect1.sectionName.equals("__text"));
  EXPECT_EQ((uint32_t)(sect1.type), (uint32_t)(llvm::MachO::S_REGULAR));
  EXPECT_EQ((uint32_t)(sect1.attributes),
                            (uint32_t)(llvm::MachO::S_ATTR_PURE_INSTRUCTIONS
                                     | llvm::MachO::S_ATTR_SOME_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)sect1.alignment, 1U);
  EXPECT_EQ((uint64_t)sect1.address, 0x0ULL);
  EXPECT_EQ(sect1.content.size(), 22UL);
  EXPECT_EQ((int)(sect1.content[0]), 0x55);
  EXPECT_EQ((int)(sect1.content[1]), 0x48);
  EXPECT_EQ(sect1.relocations.size(), 2UL);
  const Relocation& reloc1 = sect1.relocations[0];
  EXPECT_EQ(reloc1.offset, 0x0eU);
  EXPECT_FALSE(reloc1.scattered);
  EXPECT_EQ((int)reloc1.type, (int)llvm::MachO::X86_64_RELOC_BRANCH);
  EXPECT_EQ(reloc1.length, 2);
  EXPECT_TRUE(reloc1.pcRel);
  EXPECT_TRUE(reloc1.isExtern);
  EXPECT_EQ(reloc1.symbol, 2U);
  EXPECT_EQ((int)(reloc1.value), 0);
  const Relocation& reloc2 = sect1.relocations[1];
  EXPECT_EQ(reloc2.offset, 0x07U);
  EXPECT_FALSE(reloc2.scattered);
  EXPECT_EQ((int)reloc2.type, (int)llvm::MachO::X86_64_RELOC_SIGNED);
  EXPECT_EQ(reloc2.length, 2);
  EXPECT_TRUE(reloc2.pcRel);
  EXPECT_TRUE(reloc2.isExtern);
  EXPECT_EQ(reloc2.symbol, 1U);
  EXPECT_EQ((int)(reloc2.value), 0);

  const Section& sect2 = f->sections[1];
  EXPECT_TRUE(sect2.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect2.sectionName.equals("__cstring"));
  EXPECT_EQ((uint32_t)(sect2.type), (uint32_t)(llvm::MachO::S_CSTRING_LITERALS));
  EXPECT_EQ((uint32_t)(sect2.attributes), 0U);
  EXPECT_EQ((uint16_t)sect2.alignment, 1U);
  EXPECT_EQ((uint64_t)sect2.address, 0x016ULL);
  EXPECT_EQ(sect2.content.size(), 7UL);
  EXPECT_EQ((int)(sect2.content[0]), 0x68);
  EXPECT_EQ((int)(sect2.content[1]), 0x65);
  EXPECT_EQ((int)(sect2.content[2]), 0x6c);

  EXPECT_EQ(f->globalSymbols.size(), 1UL);
  const Symbol& sym1 = f->globalSymbols[0];
  EXPECT_TRUE(sym1.name.equals("_main"));
  EXPECT_EQ((int)(sym1.type), llvm::MachO::N_SECT);
  EXPECT_EQ((int)(sym1.scope), llvm::MachO::N_EXT);
  EXPECT_EQ(sym1.sect, 1);
  EXPECT_EQ((int)(sym1.desc), 0);
  EXPECT_EQ((uint64_t)sym1.value, 0x0ULL);
  EXPECT_EQ(f->localSymbols.size(), 1UL);
  const Symbol& sym2 = f->localSymbols[0];
  EXPECT_TRUE(sym2.name.equals("L_.str"));
  EXPECT_EQ((int)(sym2.type), llvm::MachO::N_SECT);
  EXPECT_EQ((int)(sym2.scope), 0);
  EXPECT_EQ(sym2.sect, 2);
  EXPECT_EQ((int)(sym2.desc), 0);
  EXPECT_EQ((uint64_t)sym2.value, 0x16ULL);
  EXPECT_EQ(f->undefinedSymbols.size(), 1UL);
  const Symbol& sym3 = f->undefinedSymbols[0];
  EXPECT_TRUE(sym3.name.equals("_printf"));
  EXPECT_EQ((int)(sym3.type), llvm::MachO::N_UNDF);
  EXPECT_EQ((int)(sym3.scope), 0);
  EXPECT_EQ(sym3.sect, 0);
  EXPECT_EQ((int)(sym3.desc), 0);
  EXPECT_EQ((uint64_t)sym3.value, 0x0ULL);
}

TEST(ObjectFileYAML, hello_x86) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      x86\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "sections:\n"
    "  - segment:     __TEXT\n"
    "    section:     __text\n"
    "    type:        S_REGULAR\n"
    "    attributes:  [ S_ATTR_PURE_INSTRUCTIONS, S_ATTR_SOME_INSTRUCTIONS]\n"
    "    alignment:   1\n"
    "    address:     0x0000\n"
    "    content:     [ 0x55, 0x89, 0xe5, 0x83, 0xec, 0x08, 0xe8, 0x00,\n"
    "                   0x00, 0x00, 0x00, 0x58, 0x8d, 0x80, 0x16, 0x00,\n"
    "                   0x00, 0x00, 0x89, 0x04, 0x24, 0xe8, 0xe6, 0xff,\n"
    "                   0xff, 0xff, 0x31, 0xc0, 0x83, 0xc4, 0x08, 0x5d,\n"
    "                   0xc3 ]\n"
    "    relocations:\n"
    "     - offset:     0x16\n"
    "       type:       GENERIC_RELOC_VANILLA\n"
    "       length:     2\n"
    "       pc-rel:     true\n"
    "       extern:     true\n"
    "       symbol:     1\n"
    "     - offset:     0x0e\n"
    "       scattered:  true\n"
    "       type:       GENERIC_RELOC_LOCAL_SECTDIFF\n"
    "       length:     2\n"
    "       pc-rel:     false\n"
    "       value:      0x21\n"
    "     - offset:     0x0\n"
    "       scattered:  true\n"
    "       type:       GENERIC_RELOC_PAIR\n"
    "       length:     2\n"
    "       pc-rel:     false\n"
    "       value:      0xb\n"
    "  - segment:     __TEXT\n"
    "    section:     __cstring\n"
    "    type:        S_CSTRING_LITERALS\n"
    "    attributes:  [ ]\n"
    "    alignment:   1\n"
    "    address:     0x0021\n"
    "    content:     [ 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x0a, 0x00 ]\n"
    "global-symbols:\n"
    "  - name:   _main\n"
    "    type:   N_SECT\n"
    "    scope:  [ N_EXT ]\n"
    "    sect:   1\n"
    "    value:  0x0\n"
    "undefined-symbols:\n"
    "  - name:   _printf\n"
    "    type:   N_UNDF\n"
    "    value:  0x0\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_x86);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_EQ(f->sections.size(), 2UL);

  const Section& sect1 = f->sections[0];
  EXPECT_TRUE(sect1.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect1.sectionName.equals("__text"));
  EXPECT_EQ((uint32_t)(sect1.type), (uint32_t)(llvm::MachO::S_REGULAR));
  EXPECT_EQ((uint32_t)(sect1.attributes),
                            (uint32_t)(llvm::MachO::S_ATTR_PURE_INSTRUCTIONS
                                     | llvm::MachO::S_ATTR_SOME_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)sect1.alignment, 1U);
  EXPECT_EQ((uint64_t)sect1.address, 0x0ULL);
  EXPECT_EQ(sect1.content.size(), 33UL);
  EXPECT_EQ((int)(sect1.content[0]), 0x55);
  EXPECT_EQ((int)(sect1.content[1]), 0x89);
  EXPECT_EQ(sect1.relocations.size(), 3UL);
  const Relocation& reloc1 = sect1.relocations[0];
  EXPECT_EQ(reloc1.offset, 0x16U);
  EXPECT_FALSE(reloc1.scattered);
  EXPECT_EQ((int)reloc1.type, (int)llvm::MachO::GENERIC_RELOC_VANILLA);
  EXPECT_EQ(reloc1.length, 2);
  EXPECT_TRUE(reloc1.pcRel);
  EXPECT_TRUE(reloc1.isExtern);
  EXPECT_EQ(reloc1.symbol, 1U);
  EXPECT_EQ((int)(reloc1.value), 0);
  const Relocation& reloc2 = sect1.relocations[1];
  EXPECT_EQ(reloc2.offset, 0x0eU);
  EXPECT_TRUE(reloc2.scattered);
  EXPECT_EQ((int)reloc2.type, (int)llvm::MachO::GENERIC_RELOC_LOCAL_SECTDIFF);
  EXPECT_EQ(reloc2.length, 2);
  EXPECT_FALSE(reloc2.pcRel);
  EXPECT_EQ(reloc2.symbol, 0U);
  EXPECT_EQ((int)(reloc2.value), 0x21);
  const Relocation& reloc3 = sect1.relocations[2];
  EXPECT_EQ(reloc3.offset, 0U);
  EXPECT_TRUE(reloc3.scattered);
  EXPECT_EQ((int)reloc3.type, (int)llvm::MachO::GENERIC_RELOC_PAIR);
  EXPECT_EQ(reloc3.length, 2);
  EXPECT_FALSE(reloc3.pcRel);
  EXPECT_EQ(reloc3.symbol, 0U);
  EXPECT_EQ((int)(reloc3.value), 0xb);

  const Section& sect2 = f->sections[1];
  EXPECT_TRUE(sect2.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect2.sectionName.equals("__cstring"));
  EXPECT_EQ((uint32_t)(sect2.type), (uint32_t)(llvm::MachO::S_CSTRING_LITERALS));
  EXPECT_EQ((uint32_t)(sect2.attributes), 0U);
  EXPECT_EQ((uint16_t)sect2.alignment, 1U);
  EXPECT_EQ((uint64_t)sect2.address, 0x021ULL);
  EXPECT_EQ(sect2.content.size(), 7UL);
  EXPECT_EQ((int)(sect2.content[0]), 0x68);
  EXPECT_EQ((int)(sect2.content[1]), 0x65);
  EXPECT_EQ((int)(sect2.content[2]), 0x6c);

  EXPECT_EQ(f->globalSymbols.size(), 1UL);
  const Symbol& sym1 = f->globalSymbols[0];
  EXPECT_TRUE(sym1.name.equals("_main"));
  EXPECT_EQ((int)(sym1.type), llvm::MachO::N_SECT);
  EXPECT_EQ((int)(sym1.scope), llvm::MachO::N_EXT);
  EXPECT_EQ(sym1.sect, 1);
  EXPECT_EQ((int)(sym1.desc), 0);
  EXPECT_EQ((uint64_t)sym1.value, 0x0ULL);
  EXPECT_EQ(f->undefinedSymbols.size(), 1UL);
  const Symbol& sym2 = f->undefinedSymbols[0];
  EXPECT_TRUE(sym2.name.equals("_printf"));
  EXPECT_EQ((int)(sym2.type), llvm::MachO::N_UNDF);
  EXPECT_EQ((int)(sym2.scope), 0);
  EXPECT_EQ(sym2.sect, 0);
  EXPECT_EQ((int)(sym2.desc), 0);
  EXPECT_EQ((uint64_t)sym2.value, 0x0ULL);
}

TEST(ObjectFileYAML, hello_armv6) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      armv6\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "sections:\n"
    "  - segment:     __TEXT\n"
    "    section:     __text\n"
    "    type:        S_REGULAR\n"
    "    attributes:  [ S_ATTR_PURE_INSTRUCTIONS, S_ATTR_SOME_INSTRUCTIONS]\n"
    "    alignment:   4\n"
    "    address:     0x0000\n"
    "    content:     [ 0x80, 0x40, 0x2d, 0xe9, 0x10, 0x00, 0x9f, 0xe5,\n"
    "                   0x0d, 0x70, 0xa0, 0xe1, 0x00, 0x00, 0x8f, 0xe0,\n"
    "                   0xfa, 0xff, 0xff, 0xeb, 0x00, 0x00, 0xa0, 0xe3,\n"
    "                   0x80, 0x80, 0xbd, 0xe8, 0x0c, 0x00, 0x00, 0x00 ]\n"
    "    relocations:\n"
    "     - offset:     0x1c\n"
    "       scattered:  true\n"
    "       type:       ARM_RELOC_SECTDIFF\n"
    "       length:     2\n"
    "       pc-rel:     false\n"
    "       value:      0x20\n"
    "     - offset:     0x0\n"
    "       scattered:  true\n"
    "       type:       ARM_RELOC_PAIR\n"
    "       length:     2\n"
    "       pc-rel:     false\n"
    "       value:      0xc\n"
    "     - offset:     0x10\n"
    "       type:       ARM_RELOC_BR24\n"
    "       length:     2\n"
    "       pc-rel:     true\n"
    "       extern:     true\n"
    "       symbol:     1\n"
    "  - segment:     __TEXT\n"
    "    section:     __cstring\n"
    "    type:        S_CSTRING_LITERALS\n"
    "    attributes:  [ ]\n"
    "    alignment:   1\n"
    "    address:     0x0020\n"
    "    content:     [ 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x0a, 0x00 ]\n"
    "global-symbols:\n"
    "  - name:   _main\n"
    "    type:   N_SECT\n"
    "    scope:  [ N_EXT ]\n"
    "    sect:   1\n"
    "    value:  0x0\n"
    "undefined-symbols:\n"
    "  - name:   _printf\n"
    "    type:   N_UNDF\n"
    "    value:  0x0\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_armv6);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_EQ(f->sections.size(), 2UL);

  const Section& sect1 = f->sections[0];
  EXPECT_TRUE(sect1.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect1.sectionName.equals("__text"));
  EXPECT_EQ((uint32_t)(sect1.type), (uint32_t)(llvm::MachO::S_REGULAR));
  EXPECT_EQ((uint32_t)(sect1.attributes),
                            (uint32_t)(llvm::MachO::S_ATTR_PURE_INSTRUCTIONS
                                     | llvm::MachO::S_ATTR_SOME_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)sect1.alignment, 4U);
  EXPECT_EQ((uint64_t)sect1.address, 0x0ULL);
  EXPECT_EQ(sect1.content.size(), 32UL);
  EXPECT_EQ((int)(sect1.content[0]), 0x80);
  EXPECT_EQ((int)(sect1.content[1]), 0x40);
  EXPECT_EQ(sect1.relocations.size(), 3UL);
  const Relocation& reloc1 = sect1.relocations[0];
  EXPECT_EQ(reloc1.offset, 0x1cU);
  EXPECT_TRUE(reloc1.scattered);
  EXPECT_EQ((int)reloc1.type, (int)llvm::MachO::ARM_RELOC_SECTDIFF);
  EXPECT_EQ(reloc1.length, 2);
  EXPECT_FALSE(reloc1.pcRel);
  EXPECT_EQ(reloc1.symbol, 0U);
  EXPECT_EQ((int)(reloc1.value), 0x20);
  const Relocation& reloc2 = sect1.relocations[1];
  EXPECT_EQ(reloc2.offset, 0x0U);
  EXPECT_TRUE(reloc2.scattered);
  EXPECT_EQ((int)reloc2.type, (int)llvm::MachO::ARM_RELOC_PAIR);
  EXPECT_EQ(reloc2.length, 2);
  EXPECT_FALSE(reloc2.pcRel);
  EXPECT_EQ(reloc2.symbol, 0U);
  EXPECT_EQ((int)(reloc2.value), 0xc);
  const Relocation& reloc3 = sect1.relocations[2];
  EXPECT_EQ(reloc3.offset, 0x10U);
  EXPECT_FALSE(reloc3.scattered);
  EXPECT_EQ((int)reloc3.type, (int)llvm::MachO::ARM_RELOC_BR24);
  EXPECT_EQ(reloc3.length, 2);
  EXPECT_TRUE(reloc3.pcRel);
  EXPECT_TRUE(reloc3.isExtern);
  EXPECT_EQ(reloc3.symbol, 1U);
  EXPECT_EQ((int)(reloc3.value), 0);

  const Section& sect2 = f->sections[1];
  EXPECT_TRUE(sect2.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect2.sectionName.equals("__cstring"));
  EXPECT_EQ((uint32_t)(sect2.type), (uint32_t)(llvm::MachO::S_CSTRING_LITERALS));
  EXPECT_EQ((uint32_t)(sect2.attributes), 0U);
  EXPECT_EQ((uint16_t)sect2.alignment, 1U);
  EXPECT_EQ((uint64_t)sect2.address, 0x020ULL);
  EXPECT_EQ(sect2.content.size(), 7UL);
  EXPECT_EQ((int)(sect2.content[0]), 0x68);
  EXPECT_EQ((int)(sect2.content[1]), 0x65);
  EXPECT_EQ((int)(sect2.content[2]), 0x6c);

  EXPECT_EQ(f->globalSymbols.size(), 1UL);
  const Symbol& sym1 = f->globalSymbols[0];
  EXPECT_TRUE(sym1.name.equals("_main"));
  EXPECT_EQ((int)(sym1.type), llvm::MachO::N_SECT);
  EXPECT_EQ((int)(sym1.scope), llvm::MachO::N_EXT);
  EXPECT_EQ(sym1.sect, 1);
  EXPECT_EQ((int)(sym1.desc), 0);
  EXPECT_EQ((uint64_t)sym1.value, 0x0ULL);
  EXPECT_EQ(f->undefinedSymbols.size(), 1UL);
  const Symbol& sym2 = f->undefinedSymbols[0];
  EXPECT_TRUE(sym2.name.equals("_printf"));
  EXPECT_EQ((int)(sym2.type), llvm::MachO::N_UNDF);
  EXPECT_EQ((int)(sym2.scope), 0);
  EXPECT_EQ(sym2.sect, 0);
  EXPECT_EQ((int)(sym2.desc), 0);
  EXPECT_EQ((uint64_t)sym2.value, 0x0ULL);
}

TEST(ObjectFileYAML, hello_armv7) {
  std::unique_ptr<NormalizedFile> f = fromYAML(
    "---\n"
    "arch:      armv7\n"
    "file-type: MH_OBJECT\n"
    "flags:     [ MH_SUBSECTIONS_VIA_SYMBOLS ]\n"
    "sections:\n"
    "  - segment:     __TEXT\n"
    "    section:     __text\n"
    "    type:        S_REGULAR\n"
    "    attributes:  [ S_ATTR_PURE_INSTRUCTIONS, S_ATTR_SOME_INSTRUCTIONS]\n"
    "    alignment:   2\n"
    "    address:     0x0000\n"
    "    content:     [ 0x80, 0xb5, 0x40, 0xf2, 0x06, 0x00, 0x6f, 0x46,\n"
    "                   0xc0, 0xf2, 0x00, 0x00, 0x78, 0x44, 0xff, 0xf7,\n"
    "                   0xf8, 0xef, 0x00, 0x20, 0x80, 0xbd ]\n"
    "    relocations:\n"
    "     - offset:     0x0e\n"
    "       type:       ARM_THUMB_RELOC_BR22\n"
    "       length:     2\n"
    "       pc-rel:     true\n"
    "       extern:     true\n"
    "       symbol:     1\n"
    "     - offset:     0x08\n"
    "       scattered:  true\n"
    "       type:       ARM_RELOC_HALF_SECTDIFF\n"
    "       length:     3\n"
    "       pc-rel:     false\n"
    "       value:      0x16\n"
    "     - offset:     0x06\n"
    "       scattered:  true\n"
    "       type:       ARM_RELOC_PAIR\n"
    "       length:     3\n"
    "       pc-rel:     false\n"
    "       value:      0xc\n"
    "     - offset:     0x02\n"
    "       scattered:  true\n"
    "       type:       ARM_RELOC_HALF_SECTDIFF\n"
    "       length:     2\n"
    "       pc-rel:     false\n"
    "       value:      0x16\n"
    "     - offset:     0x0\n"
    "       scattered:  true\n"
    "       type:       ARM_RELOC_PAIR\n"
    "       length:     2\n"
    "       pc-rel:     false\n"
    "       value:      0xc\n"
    "  - segment:     __TEXT\n"
    "    section:     __cstring\n"
    "    type:        S_CSTRING_LITERALS\n"
    "    attributes:  [ ]\n"
    "    alignment:   1\n"
    "    address:     0x0016\n"
    "    content:     [ 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x0a, 0x00 ]\n"
    "global-symbols:\n"
    "  - name:   _main\n"
    "    type:   N_SECT\n"
    "    scope:  [ N_EXT ]\n"
    "    sect:   1\n"
    "    desc:   [ N_ARM_THUMB_DEF ]\n"
    "    value:  0x0\n"
    "undefined-symbols:\n"
    "  - name:   _printf\n"
    "    type:   N_UNDF\n"
    "    value:  0x0\n"
    "...\n");
  EXPECT_EQ(f->arch, lld::MachOLinkingContext::arch_armv7);
  EXPECT_EQ(f->fileType, llvm::MachO::MH_OBJECT);
  EXPECT_EQ((int)(f->flags), llvm::MachO::MH_SUBSECTIONS_VIA_SYMBOLS);
  EXPECT_EQ(f->sections.size(), 2UL);

  const Section& sect1 = f->sections[0];
  EXPECT_TRUE(sect1.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect1.sectionName.equals("__text"));
  EXPECT_EQ((uint32_t)(sect1.type), (uint32_t)(llvm::MachO::S_REGULAR));
  EXPECT_EQ((uint32_t)(sect1.attributes),
                            (uint32_t)(llvm::MachO::S_ATTR_PURE_INSTRUCTIONS
                                     | llvm::MachO::S_ATTR_SOME_INSTRUCTIONS));
  EXPECT_EQ((uint16_t)sect1.alignment, 2U);
  EXPECT_EQ((uint64_t)sect1.address, 0x0ULL);
  EXPECT_EQ(sect1.content.size(), 22UL);
  EXPECT_EQ((int)(sect1.content[0]), 0x80);
  EXPECT_EQ((int)(sect1.content[1]), 0xb5);
  EXPECT_EQ(sect1.relocations.size(), 5UL);
  const Relocation& reloc1 = sect1.relocations[0];
  EXPECT_EQ(reloc1.offset, 0x0eU);
  EXPECT_FALSE(reloc1.scattered);
  EXPECT_EQ((int)reloc1.type, (int)llvm::MachO::ARM_THUMB_RELOC_BR22);
  EXPECT_EQ(reloc1.length, 2);
  EXPECT_TRUE(reloc1.pcRel);
  EXPECT_TRUE(reloc1.isExtern);
  EXPECT_EQ(reloc1.symbol, 1U);
  EXPECT_EQ((int)(reloc1.value), 0);
  const Relocation& reloc2 = sect1.relocations[1];
  EXPECT_EQ(reloc2.offset, 0x8U);
  EXPECT_TRUE(reloc2.scattered);
  EXPECT_EQ((int)reloc2.type, (int)llvm::MachO::ARM_RELOC_HALF_SECTDIFF);
  EXPECT_EQ(reloc2.length, 3);
  EXPECT_FALSE(reloc2.pcRel);
  EXPECT_EQ(reloc2.symbol, 0U);
  EXPECT_EQ((int)(reloc2.value), 0x16);
  const Relocation& reloc3 = sect1.relocations[2];
  EXPECT_EQ(reloc3.offset, 0x6U);
  EXPECT_TRUE(reloc3.scattered);
  EXPECT_EQ((int)reloc3.type, (int)llvm::MachO::ARM_RELOC_PAIR);
  EXPECT_EQ(reloc3.length, 3);
  EXPECT_FALSE(reloc3.pcRel);
  EXPECT_EQ(reloc3.symbol, 0U);
  EXPECT_EQ((int)(reloc3.value), 0xc);
   const Relocation& reloc4 = sect1.relocations[3];
  EXPECT_EQ(reloc4.offset, 0x2U);
  EXPECT_TRUE(reloc4.scattered);
  EXPECT_EQ((int)reloc4.type, (int)llvm::MachO::ARM_RELOC_HALF_SECTDIFF);
  EXPECT_EQ(reloc4.length, 2);
  EXPECT_FALSE(reloc4.pcRel);
  EXPECT_EQ(reloc4.symbol, 0U);
  EXPECT_EQ((int)(reloc4.value), 0x16);
  const Relocation& reloc5 = sect1.relocations[4];
  EXPECT_EQ(reloc5.offset, 0x0U);
  EXPECT_TRUE(reloc5.scattered);
  EXPECT_EQ((int)reloc5.type, (int)llvm::MachO::ARM_RELOC_PAIR);
  EXPECT_EQ(reloc5.length, 2);
  EXPECT_FALSE(reloc5.pcRel);
  EXPECT_EQ(reloc5.symbol, 0U);
  EXPECT_EQ((int)(reloc5.value), 0xc);

  const Section& sect2 = f->sections[1];
  EXPECT_TRUE(sect2.segmentName.equals("__TEXT"));
  EXPECT_TRUE(sect2.sectionName.equals("__cstring"));
  EXPECT_EQ((uint32_t)(sect2.type), (uint32_t)(llvm::MachO::S_CSTRING_LITERALS));
  EXPECT_EQ((uint32_t)(sect2.attributes), 0U);
  EXPECT_EQ((uint16_t)sect2.alignment, 1U);
  EXPECT_EQ((uint64_t)sect2.address, 0x016ULL);
  EXPECT_EQ(sect2.content.size(), 7UL);
  EXPECT_EQ((int)(sect2.content[0]), 0x68);
  EXPECT_EQ((int)(sect2.content[1]), 0x65);
  EXPECT_EQ((int)(sect2.content[2]), 0x6c);

  EXPECT_EQ(f->globalSymbols.size(), 1UL);
  const Symbol& sym1 = f->globalSymbols[0];
  EXPECT_TRUE(sym1.name.equals("_main"));
  EXPECT_EQ((int)(sym1.type), llvm::MachO::N_SECT);
  EXPECT_EQ((int)(sym1.scope), llvm::MachO::N_EXT);
  EXPECT_EQ(sym1.sect, 1);
  EXPECT_EQ((int)(sym1.desc), (int)(llvm::MachO::N_ARM_THUMB_DEF));
  EXPECT_EQ((uint64_t)sym1.value, 0x0ULL);
  EXPECT_EQ(f->undefinedSymbols.size(), 1UL);
  const Symbol& sym2 = f->undefinedSymbols[0];
  EXPECT_TRUE(sym2.name.equals("_printf"));
  EXPECT_EQ((int)(sym2.type), llvm::MachO::N_UNDF);
  EXPECT_EQ((int)(sym2.scope), 0);
  EXPECT_EQ(sym2.sect, 0);
  EXPECT_EQ((int)(sym2.desc), 0);
  EXPECT_EQ((uint64_t)sym2.value, 0x0ULL);
}
