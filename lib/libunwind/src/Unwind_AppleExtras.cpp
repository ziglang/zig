//===--------------------- Unwind_AppleExtras.cpp -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//
//===----------------------------------------------------------------------===//

#include "config.h"


// static linker symbols to prevent wrong two level namespace for _Unwind symbols
#if defined(__arm__)
   #define NOT_HERE_BEFORE_5_0(sym)     \
       extern const char sym##_tmp30 __asm("$ld$hide$os3.0$_" #sym ); \
       __attribute__((visibility("default"))) const char sym##_tmp30 = 0; \
       extern const char sym##_tmp31 __asm("$ld$hide$os3.1$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp31 = 0; \
       extern const char sym##_tmp32 __asm("$ld$hide$os3.2$_" #sym );\
           __attribute__((visibility("default"))) const char sym##_tmp32 = 0; \
       extern const char sym##_tmp40 __asm("$ld$hide$os4.0$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp40 = 0; \
       extern const char sym##_tmp41 __asm("$ld$hide$os4.1$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp41 = 0; \
       extern const char sym##_tmp42 __asm("$ld$hide$os4.2$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp42 = 0; \
       extern const char sym##_tmp43 __asm("$ld$hide$os4.3$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp43 = 0;
#elif defined(__aarch64__)
  #define NOT_HERE_BEFORE_10_6(sym)
  #define NEVER_HERE(sym)
#else
  #define NOT_HERE_BEFORE_10_6(sym) \
    extern const char sym##_tmp4 __asm("$ld$hide$os10.4$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp4 = 0; \
    extern const char sym##_tmp5 __asm("$ld$hide$os10.5$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp5 = 0;
  #define NEVER_HERE(sym) \
    extern const char sym##_tmp4 __asm("$ld$hide$os10.4$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp4 = 0; \
    extern const char sym##_tmp5 __asm("$ld$hide$os10.5$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp5 = 0; \
    extern const char sym##_tmp6 __asm("$ld$hide$os10.6$_" #sym ); \
          __attribute__((visibility("default"))) const char sym##_tmp6 = 0;
#endif


#if defined(_LIBUNWIND_BUILD_ZERO_COST_APIS)

//
// symbols in libSystem.dylib in 10.6 and later, but are in libgcc_s.dylib in
// earlier versions
//
NOT_HERE_BEFORE_10_6(_Unwind_DeleteException)
NOT_HERE_BEFORE_10_6(_Unwind_Find_FDE)
NOT_HERE_BEFORE_10_6(_Unwind_ForcedUnwind)
NOT_HERE_BEFORE_10_6(_Unwind_GetGR)
NOT_HERE_BEFORE_10_6(_Unwind_GetIP)
NOT_HERE_BEFORE_10_6(_Unwind_GetLanguageSpecificData)
NOT_HERE_BEFORE_10_6(_Unwind_GetRegionStart)
NOT_HERE_BEFORE_10_6(_Unwind_RaiseException)
NOT_HERE_BEFORE_10_6(_Unwind_Resume)
NOT_HERE_BEFORE_10_6(_Unwind_SetGR)
NOT_HERE_BEFORE_10_6(_Unwind_SetIP)
NOT_HERE_BEFORE_10_6(_Unwind_Backtrace)
NOT_HERE_BEFORE_10_6(_Unwind_FindEnclosingFunction)
NOT_HERE_BEFORE_10_6(_Unwind_GetCFA)
NOT_HERE_BEFORE_10_6(_Unwind_GetDataRelBase)
NOT_HERE_BEFORE_10_6(_Unwind_GetTextRelBase)
NOT_HERE_BEFORE_10_6(_Unwind_Resume_or_Rethrow)
NOT_HERE_BEFORE_10_6(_Unwind_GetIPInfo)
NOT_HERE_BEFORE_10_6(__register_frame)
NOT_HERE_BEFORE_10_6(__deregister_frame)

//
// symbols in libSystem.dylib for compatibility, but we don't want any new code
// using them
//
NEVER_HERE(__register_frame_info_bases)
NEVER_HERE(__register_frame_info)
NEVER_HERE(__register_frame_info_table_bases)
NEVER_HERE(__register_frame_info_table)
NEVER_HERE(__register_frame_table)
NEVER_HERE(__deregister_frame_info)
NEVER_HERE(__deregister_frame_info_bases)

#endif // defined(_LIBUNWIND_BUILD_ZERO_COST_APIS)




#if defined(_LIBUNWIND_BUILD_SJLJ_APIS)
//
// symbols in libSystem.dylib in iOS 5.0 and later, but are in libgcc_s.dylib in
// earlier versions
//
NOT_HERE_BEFORE_5_0(_Unwind_GetLanguageSpecificData)
NOT_HERE_BEFORE_5_0(_Unwind_GetRegionStart)
NOT_HERE_BEFORE_5_0(_Unwind_GetIP)
NOT_HERE_BEFORE_5_0(_Unwind_SetGR)
NOT_HERE_BEFORE_5_0(_Unwind_SetIP)
NOT_HERE_BEFORE_5_0(_Unwind_DeleteException)
NOT_HERE_BEFORE_5_0(_Unwind_SjLj_Register)
NOT_HERE_BEFORE_5_0(_Unwind_GetGR)
NOT_HERE_BEFORE_5_0(_Unwind_GetIPInfo)
NOT_HERE_BEFORE_5_0(_Unwind_GetCFA)
NOT_HERE_BEFORE_5_0(_Unwind_SjLj_Resume)
NOT_HERE_BEFORE_5_0(_Unwind_SjLj_RaiseException)
NOT_HERE_BEFORE_5_0(_Unwind_SjLj_Resume_or_Rethrow)
NOT_HERE_BEFORE_5_0(_Unwind_SjLj_Unregister)

#endif // defined(_LIBUNWIND_BUILD_SJLJ_APIS)
