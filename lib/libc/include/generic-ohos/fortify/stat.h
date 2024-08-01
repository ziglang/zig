/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _SYS_STAT_H
#error "Never include this file directly; instead, include <sys/stat.h>"
#endif

#include "fortify.h"

#ifdef __cplusplus
extern "C" {
#endif

mode_t __umask_chk(mode_t);
mode_t __umask_real(mode_t mode) __DIAGNOSE_RENAME(umask);

#ifdef __FORTIFY_COMPILATION
/* Overload of umask. */
__DIAGNOSE_FORTIFY_INLINE
mode_t umask(mode_t mode)
__DIAGNOSE_OVERLOAD
__DIAGNOSE_ENABLE_IF(1, "")
__DIAGNOSE_ERROR_IF(mode & ~0777, "'umask' was called in invalid mode")
{
#ifdef __FORTIFY_RUNTIME
    return __umask_chk(mode);
#else
    return __umask_real(mode);
#endif
}
#endif

#ifdef __cplusplus
}
#endif