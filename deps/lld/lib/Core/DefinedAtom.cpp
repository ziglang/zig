//===- DefinedAtom.cpp ------------------------------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Support/ErrorHandling.h"
#include "lld/Core/DefinedAtom.h"
#include "lld/Core/File.h"

namespace lld {

DefinedAtom::ContentPermissions DefinedAtom::permissions() const {
  // By default base permissions on content type.
  return permissions(this->contentType());
}

// Utility function for deriving permissions from content type
DefinedAtom::ContentPermissions DefinedAtom::permissions(ContentType type) {
  switch (type) {
  case typeCode:
  case typeResolver:
  case typeBranchIsland:
  case typeBranchShim:
  case typeStub:
  case typeStubHelper:
  case typeMachHeader:
    return permR_X;

  case typeConstant:
  case typeCString:
  case typeUTF16String:
  case typeCFI:
  case typeLSDA:
  case typeLiteral4:
  case typeLiteral8:
  case typeLiteral16:
  case typeDTraceDOF:
  case typeCompactUnwindInfo:
  case typeProcessedUnwindInfo:
  case typeObjCImageInfo:
  case typeObjCMethodList:
    return permR__;

  case typeData:
  case typeDataFast:
  case typeZeroFill:
  case typeZeroFillFast:
  case typeObjC1Class:
  case typeLazyPointer:
  case typeLazyDylibPointer:
  case typeNonLazyPointer:
  case typeThunkTLV:
    return permRW_;

  case typeGOT:
  case typeConstData:
  case typeCFString:
  case typeInitializerPtr:
  case typeTerminatorPtr:
  case typeCStringPtr:
  case typeObjCClassPtr:
  case typeObjC2CategoryList:
  case typeInterposingTuples:
  case typeTLVInitialData:
  case typeTLVInitialZeroFill:
  case typeTLVInitializerPtr:
    return permRW_L;

  case typeUnknown:
  case typeTempLTO:
  case typeSectCreate:
  case typeDSOHandle:
    return permUnknown;
  }
  llvm_unreachable("unknown content type");
}

} // namespace
