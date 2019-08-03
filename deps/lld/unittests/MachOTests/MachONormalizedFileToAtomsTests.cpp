//===- lld/unittest/MachOTests/MachONormalizedFileToAtomsTests.cpp --------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "../../lib/ReaderWriter/MachO/MachONormalizedFile.h"
#include "lld/Core/Atom.h"
#include "lld/Core/DefinedAtom.h"
#include "lld/Core/File.h"
#include "lld/Core/UndefinedAtom.h"
#include "lld/ReaderWriter/MachOLinkingContext.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/BinaryFormat/MachO.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/YAMLTraits.h"
#include "gtest/gtest.h"
#include <cstdint>
#include <memory>

using namespace lld::mach_o::normalized;
using namespace llvm::MachO;

TEST(ToAtomsTest, empty_obj_x86_64) {
  NormalizedFile f;
  f.arch = lld::MachOLinkingContext::arch_x86_64;
  llvm::Expected<std::unique_ptr<const lld::File>> atom_f =
      normalizedToAtoms(f, "", false);
  EXPECT_FALSE(!atom_f);
  EXPECT_EQ(0U, (*atom_f)->defined().size());
}

TEST(ToAtomsTest, basic_obj_x86_64) {
  NormalizedFile f;
  f.arch = lld::MachOLinkingContext::arch_x86_64;
  Section textSection;
  static const uint8_t contentBytes[] = { 0x90, 0xC3, 0xC3, 0xC4 };
  const unsigned contentSize = sizeof(contentBytes) / sizeof(contentBytes[0]);
  textSection.content = llvm::makeArrayRef(contentBytes, contentSize);
  f.sections.push_back(textSection);
  Symbol fooSymbol;
  fooSymbol.name = "_foo";
  fooSymbol.type = N_SECT;
  fooSymbol.scope = N_EXT;
  fooSymbol.sect = 1;
  fooSymbol.value = 0;
  f.globalSymbols.push_back(fooSymbol);
  Symbol barSymbol;
  barSymbol.name = "_bar";
  barSymbol.type = N_SECT;
  barSymbol.scope = N_EXT;
  barSymbol.sect = 1;
  barSymbol.value = 2;
  f.globalSymbols.push_back(barSymbol);
  Symbol undefSym;
  undefSym.name = "_undef";
  undefSym.type = N_UNDF;
  f.undefinedSymbols.push_back(undefSym);
  Symbol bazSymbol;
  bazSymbol.name = "_baz";
  bazSymbol.type = N_SECT;
  bazSymbol.scope = N_EXT | N_PEXT;
  bazSymbol.sect = 1;
  bazSymbol.value = 3;
  f.localSymbols.push_back(bazSymbol);

  llvm::Expected<std::unique_ptr<const lld::File>> atom_f =
      normalizedToAtoms(f, "", false);
  EXPECT_FALSE(!atom_f);
  const lld::File &file = **atom_f;
  EXPECT_EQ(3U, file.defined().size());
  auto it = file.defined().begin();
  const lld::DefinedAtom *atom1 = *it;
  ++it;
  const lld::DefinedAtom *atom2 = *it;
  ++it;
  const lld::DefinedAtom *atom3 = *it;
  const lld::UndefinedAtom *atom4 = *file.undefined().begin();
  EXPECT_TRUE(atom1->name().equals("_foo"));
  EXPECT_EQ(2U, atom1->rawContent().size());
  EXPECT_EQ(0x90, atom1->rawContent()[0]);
  EXPECT_EQ(0xC3, atom1->rawContent()[1]);
  EXPECT_EQ(lld::Atom::scopeGlobal, atom1->scope());

  EXPECT_TRUE(atom2->name().equals("_bar"));
  EXPECT_EQ(1U, atom2->rawContent().size());
  EXPECT_EQ(0xC3, atom2->rawContent()[0]);
  EXPECT_EQ(lld::Atom::scopeGlobal, atom2->scope());

  EXPECT_TRUE(atom3->name().equals("_baz"));
  EXPECT_EQ(1U, atom3->rawContent().size());
  EXPECT_EQ(0xC4, atom3->rawContent()[0]);
  EXPECT_EQ(lld::Atom::scopeLinkageUnit, atom3->scope());

  EXPECT_TRUE(atom4->name().equals("_undef"));
  EXPECT_EQ(lld::Atom::definitionUndefined, atom4->definition());
}
