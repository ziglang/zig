//===-- sanitizer_symbolizer_mac.cpp --------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file is shared between various sanitizers' runtime libraries.
//
// Implementation of Mac-specific "atos" symbolizer.
//===----------------------------------------------------------------------===//

#include "sanitizer_platform.h"
#if SANITIZER_MAC

#include "sanitizer_allocator_internal.h"
#include "sanitizer_mac.h"
#include "sanitizer_symbolizer_mac.h"

#include <dlfcn.h>
#include <errno.h>
#include <mach/mach.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
#include <util.h>

namespace __sanitizer {

bool DlAddrSymbolizer::SymbolizePC(uptr addr, SymbolizedStack *stack) {
  Dl_info info;
  int result = dladdr((const void *)addr, &info);
  if (!result) return false;

  CHECK(addr >= reinterpret_cast<uptr>(info.dli_saddr));
  stack->info.function_offset = addr - reinterpret_cast<uptr>(info.dli_saddr);
  const char *demangled = DemangleSwiftAndCXX(info.dli_sname);
  if (!demangled) return false;
  stack->info.function = internal_strdup(demangled);
  return true;
}

bool DlAddrSymbolizer::SymbolizeData(uptr addr, DataInfo *datainfo) {
  Dl_info info;
  int result = dladdr((const void *)addr, &info);
  if (!result) return false;
  const char *demangled = DemangleSwiftAndCXX(info.dli_sname);
  datainfo->name = internal_strdup(demangled);
  datainfo->start = (uptr)info.dli_saddr;
  return true;
}

#define K_ATOS_ENV_VAR "__check_mach_ports_lookup"

// This cannot live in `AtosSymbolizerProcess` because instances of that object
// are allocated by the internal allocator which under ASan is poisoned with
// kAsanInternalHeapMagic.
static char kAtosMachPortEnvEntry[] = K_ATOS_ENV_VAR "=000000000000000";

class AtosSymbolizerProcess : public SymbolizerProcess {
 public:
  explicit AtosSymbolizerProcess(const char *path)
      : SymbolizerProcess(path, /*use_posix_spawn*/ true) {
    pid_str_[0] = '\0';
  }

  void LateInitialize() {
    if (SANITIZER_IOSSIM) {
      // `putenv()` may call malloc/realloc so it is only safe to do this
      // during LateInitialize() or later (i.e. we can't do this in the
      // constructor).  We also can't do this in `StartSymbolizerSubprocess()`
      // because in TSan we switch allocators when we're symbolizing.
      // We use `putenv()` rather than `setenv()` so that we can later directly
      // write into the storage without LibC getting involved to change what the
      // variable is set to
      int result = putenv(kAtosMachPortEnvEntry);
      CHECK_EQ(result, 0);
    }
  }

 private:
  bool StartSymbolizerSubprocess() override {
    // Configure sandbox before starting atos process.

    // Put the string command line argument in the object so that it outlives
    // the call to GetArgV.
    internal_snprintf(pid_str_, sizeof(pid_str_), "%d", internal_getpid());

    if (SANITIZER_IOSSIM) {
      // `atos` in the simulator is restricted in its ability to retrieve the
      // task port for the target process (us) so we need to do extra work
      // to pass our task port to it.
      mach_port_t ports[]{mach_task_self()};
      kern_return_t ret =
          mach_ports_register(mach_task_self(), ports, /*count=*/1);
      CHECK_EQ(ret, KERN_SUCCESS);

      // Set environment variable that signals to `atos` that it should look
      // for our task port. We can't call `setenv()` here because it might call
      // malloc/realloc. To avoid that we instead update the
      // `mach_port_env_var_entry_` variable with our current PID.
      uptr count = internal_snprintf(kAtosMachPortEnvEntry,
                                     sizeof(kAtosMachPortEnvEntry),
                                     K_ATOS_ENV_VAR "=%s", pid_str_);
      CHECK_GE(count, sizeof(K_ATOS_ENV_VAR) + internal_strlen(pid_str_));
      // Document our assumption but without calling `getenv()` in normal
      // builds.
      DCHECK(getenv(K_ATOS_ENV_VAR));
      DCHECK_EQ(internal_strcmp(getenv(K_ATOS_ENV_VAR), pid_str_), 0);
    }

    return SymbolizerProcess::StartSymbolizerSubprocess();
  }

  bool ReachedEndOfOutput(const char *buffer, uptr length) const override {
    return (length >= 1 && buffer[length - 1] == '\n');
  }

  void GetArgV(const char *path_to_binary,
               const char *(&argv)[kArgVMax]) const override {
    int i = 0;
    argv[i++] = path_to_binary;
    argv[i++] = "-p";
    argv[i++] = &pid_str_[0];
    if (GetMacosAlignedVersion() == MacosVersion(10, 9)) {
      // On Mavericks atos prints a deprecation warning which we suppress by
      // passing -d. The warning isn't present on other OSX versions, even the
      // newer ones.
      argv[i++] = "-d";
    }
    argv[i++] = nullptr;
  }

  char pid_str_[16];
  // Space for `\0` in `K_ATOS_ENV_VAR` is reused for `=`.
  static_assert(sizeof(kAtosMachPortEnvEntry) ==
                    (sizeof(K_ATOS_ENV_VAR) + sizeof(pid_str_)),
                "sizes should match");
};

#undef K_ATOS_ENV_VAR

static bool ParseCommandOutput(const char *str, uptr addr, char **out_name,
                               char **out_module, char **out_file, uptr *line,
                               uptr *start_address) {
  // Trim ending newlines.
  char *trim;
  ExtractTokenUpToDelimiter(str, "\n", &trim);

  // The line from `atos` is in one of these formats:
  //   myfunction (in library.dylib) (sourcefile.c:17)
  //   myfunction (in library.dylib) + 0x1fe
  //   myfunction (in library.dylib) + 15
  //   0xdeadbeef (in library.dylib) + 0x1fe
  //   0xdeadbeef (in library.dylib) + 15
  //   0xdeadbeef (in library.dylib)
  //   0xdeadbeef

  const char *rest = trim;
  char *symbol_name;
  rest = ExtractTokenUpToDelimiter(rest, " (in ", &symbol_name);
  if (rest[0] == '\0') {
    InternalFree(symbol_name);
    InternalFree(trim);
    return false;
  }

  if (internal_strncmp(symbol_name, "0x", 2) != 0)
    *out_name = symbol_name;
  else
    InternalFree(symbol_name);
  rest = ExtractTokenUpToDelimiter(rest, ") ", out_module);

  if (rest[0] == '(') {
    if (out_file) {
      rest++;
      rest = ExtractTokenUpToDelimiter(rest, ":", out_file);
      char *extracted_line_number;
      rest = ExtractTokenUpToDelimiter(rest, ")", &extracted_line_number);
      if (line) *line = (uptr)internal_atoll(extracted_line_number);
      InternalFree(extracted_line_number);
    }
  } else if (rest[0] == '+') {
    rest += 2;
    uptr offset = internal_atoll(rest);
    if (start_address) *start_address = addr - offset;
  }

  InternalFree(trim);
  return true;
}

AtosSymbolizer::AtosSymbolizer(const char *path, LowLevelAllocator *allocator)
    : process_(new (*allocator) AtosSymbolizerProcess(path)) {}

bool AtosSymbolizer::SymbolizePC(uptr addr, SymbolizedStack *stack) {
  if (!process_) return false;
  if (addr == 0) return false;
  char command[32];
  internal_snprintf(command, sizeof(command), "0x%zx\n", addr);
  const char *buf = process_->SendCommand(command);
  if (!buf) return false;
  uptr line;
  uptr start_address = AddressInfo::kUnknown;
  if (!ParseCommandOutput(buf, addr, &stack->info.function, &stack->info.module,
                          &stack->info.file, &line, &start_address)) {
    process_ = nullptr;
    return false;
  }
  stack->info.line = (int)line;

  if (start_address == AddressInfo::kUnknown) {
    // Fallback to dladdr() to get function start address if atos doesn't report
    // it.
    Dl_info info;
    int result = dladdr((const void *)addr, &info);
    if (result)
      start_address = reinterpret_cast<uptr>(info.dli_saddr);
  }

  // Only assig to `function_offset` if we were able to get the function's
  // start address.
  if (start_address != AddressInfo::kUnknown) {
    CHECK(addr >= start_address);
    stack->info.function_offset = addr - start_address;
  }
  return true;
}

bool AtosSymbolizer::SymbolizeData(uptr addr, DataInfo *info) {
  if (!process_) return false;
  char command[32];
  internal_snprintf(command, sizeof(command), "0x%zx\n", addr);
  const char *buf = process_->SendCommand(command);
  if (!buf) return false;
  if (!ParseCommandOutput(buf, addr, &info->name, &info->module, nullptr,
                          nullptr, &info->start)) {
    process_ = nullptr;
    return false;
  }
  return true;
}

void AtosSymbolizer::LateInitialize() { process_->LateInitialize(); }

}  // namespace __sanitizer

#endif  // SANITIZER_MAC
