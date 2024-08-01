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

#ifndef _STDLIB_H
#error "Never include this file directly; instead, include <stdlib.h>"
#endif

#include "fortify.h"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_GNU_SOURCE) && defined(__FORTIFY_COMPILATION)
char* realpath(const char* path, char* resolved)
__DIAGNOSE_ERROR_IF(!path, "'realpath': NULL path is never correct; flipped arguments?")
__DIAGNOSE_ERROR_IF(__DIAGNOSE_UNEVALUATED_LT(__DIAGNOSE_BOS(resolved), FORTIFY_PATH_MAX),
    "'realpath' " OUTPUT_PARAMETER_BYTES);
#endif
#ifdef __cplusplus
}
#endif