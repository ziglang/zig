//===- lld/Core/PassManager.h - Manage linker passes ----------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLD_CORE_PASS_MANAGER_H
#define LLD_CORE_PASS_MANAGER_H

#include "lld/Common/LLVM.h"
#include "lld/Core/Pass.h"
#include "llvm/Support/Error.h"
#include <memory>
#include <vector>

namespace lld {
class SimpleFile;
class Pass;

/// Owns and runs a collection of passes.
///
/// This class is currently just a container for passes and a way to run them.
///
/// In the future this should handle timing pass runs, running parallel passes,
/// and validate/satisfy pass dependencies.
class PassManager {
public:
  void add(std::unique_ptr<Pass> pass) {
    _passes.push_back(std::move(pass));
  }

  llvm::Error runOnFile(SimpleFile &file) {
    for (std::unique_ptr<Pass> &pass : _passes)
      if (llvm::Error EC = pass->perform(file))
        return EC;
    return llvm::Error::success();
  }

private:
  /// Passes in the order they should run.
  std::vector<std::unique_ptr<Pass>> _passes;
};
} // end namespace lld

#endif
