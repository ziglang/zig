//===- Core/SymbolTable.h - Main Symbol Table -----------------------------===//
//
//                             The LLVM Linker
//
// This file is distributed under the University of Illinois Open Source
// License. See LICENSE.TXT for details.
//
//===----------------------------------------------------------------------===//

#ifndef LLD_CORE_SYMBOL_TABLE_H
#define LLD_CORE_SYMBOL_TABLE_H

#include "lld/Core/LLVM.h"
#include "llvm/ADT/DenseSet.h"
#include "llvm/ADT/StringExtras.h"
#include <cstring>
#include <map>
#include <vector>

namespace lld {

class AbsoluteAtom;
class Atom;
class DefinedAtom;
class LinkingContext;
class ResolverOptions;
class SharedLibraryAtom;
class UndefinedAtom;

/// \brief The SymbolTable class is responsible for coalescing atoms.
///
/// All atoms coalescable by-name or by-content should be added.
/// The method replacement() can be used to find the replacement atom
/// if an atom has been coalesced away.
class SymbolTable {
public:
  /// @brief add atom to symbol table
  bool add(const DefinedAtom &);

  /// @brief add atom to symbol table
  bool add(const UndefinedAtom &);

  /// @brief add atom to symbol table
  bool add(const SharedLibraryAtom &);

  /// @brief add atom to symbol table
  bool add(const AbsoluteAtom &);

  /// @brief returns atom in symbol table for specified name (or nullptr)
  const Atom *findByName(StringRef sym);

  /// @brief returns vector of remaining UndefinedAtoms
  std::vector<const UndefinedAtom *> undefines();

  /// @brief if atom has been coalesced away, return replacement, else return atom
  const Atom *replacement(const Atom *);

  /// @brief if atom has been coalesced away, return true
  bool isCoalescedAway(const Atom *);

private:
  typedef llvm::DenseMap<const Atom *, const Atom *> AtomToAtom;

  struct StringRefMappingInfo {
    static StringRef getEmptyKey() { return StringRef(); }
    static StringRef getTombstoneKey() { return StringRef(" ", 1); }
    static unsigned getHashValue(StringRef const val) {
      return llvm::HashString(val);
    }
    static bool isEqual(StringRef const lhs, StringRef const rhs) {
      return lhs.equals(rhs);
    }
  };
  typedef llvm::DenseMap<StringRef, const Atom *,
                                           StringRefMappingInfo> NameToAtom;

  struct AtomMappingInfo {
    static const DefinedAtom * getEmptyKey() { return nullptr; }
    static const DefinedAtom * getTombstoneKey() { return (DefinedAtom*)(-1); }
    static unsigned getHashValue(const DefinedAtom * const Val);
    static bool isEqual(const DefinedAtom * const LHS,
                        const DefinedAtom * const RHS);
  };
  typedef llvm::DenseSet<const DefinedAtom*, AtomMappingInfo> AtomContentSet;

  bool addByName(const Atom &);
  bool addByContent(const DefinedAtom &);

  AtomToAtom _replacedAtoms;
  NameToAtom _nameTable;
  AtomContentSet _contentTable;
};

} // namespace lld

#endif // LLD_CORE_SYMBOL_TABLE_H
