/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef HIVIEWDFX_HIDEBUG_H
#define HIVIEWDFX_HIDEBUG_H
/**
 * @addtogroup HiDebug
 * @{
 *
 * @brief Provides debug functions.
 *
 * For example, you can use these functions to obtain cpu uage, memory, heap, capture trace.
 *
 * @since 12
 */

/**
 * @file hideug.h
 *
 * @brief Defines the debug functions of the HiDebug module.
 *
 * @library libohhidebug.so
 * @syscap SystemCapability.HiviewDFX.HiProfiler.HiDebug
 * @since 12
 */

#include <stdint.h>
#include "hidebug_type.h"

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

/**
 * @brief Obtains the cpu usage of system.
 *
 * @return Returns the cpu usage of system
 *         If the result is zero,The possible reason is that get failed.
 * @since 12
 */
double OH_HiDebug_GetSystemCpuUsage();

/**
 * @brief Obtains the cpu usage percent of a process.
 *
 * @return Returns the cpu usage percent of a process
 *         If the result is zero.The possbile reason is the current application usage rate is too low
 *         or acquisition has failed
 * @since 12
 */
double OH_HiDebug_GetAppCpuUsage();

/**
 * @brief Obtains cpu usage of application's all thread.
 *
 * @return Returns all thread cpu usage. See {@link HiDebug_ThreadCpuUsagePtr}.
 *         If the HiDebug_ThreadCpuUsagePtr is null.
 *         The possible reason is that no thread related data was obtained
 * @since 12
 */
HiDebug_ThreadCpuUsagePtr OH_HiDebug_GetAppThreadCpuUsage();

/**
 * @brief Free cpu usage buffer of application's all thread.
 *
 * @param threadCpuUsage Indicates applicatoin's all thread. See {@link HiDebug_ThreadCpuUsagePtr}
 *        Use the pointer generated through the OH_HiDebug_GetAppThreadCpuUsage().
 * @since 12
 */
void OH_HiDebug_FreeThreadCpuUsage(HiDebug_ThreadCpuUsagePtr *threadCpuUsage);

/**
 * @brief Obtains the system memory size.
 *
 * @param systemMemInfo Indicates the pointer to {@link HiDebug_SystemMemInfo}.
 *        If there is no data in structure after the function.The Possible reason is system error.
 * @since 12
 */
void OH_HiDebug_GetSystemMemInfo(HiDebug_SystemMemInfo *systemMemInfo);

/**
 * @brief Obtains the memory info of application process.
 *
 * @param nativeMemInfo Indicates the pointer to {@link HiDebug_NativeMemInfo}.
 *        If there is no data in structure after the function.The Possible reason is system error.
 * @since 12
 */
void OH_HiDebug_GetAppNativeMemInfo(HiDebug_NativeMemInfo *nativeMemInfo);

/**
 * @brief Obtains the memory limit of application process.
 *
 * @param memoryLimit Indicates the pointer to {@link HiDebug_MemoryLimit}
 *        If there is no data in structure after the function.The Possible reason is system error.
 * @since 12
 */
void OH_HiDebug_GetAppMemoryLimit(HiDebug_MemoryLimit *memoryLimit);

/**
 * @brief Start capture application trace.
 *
 * @param flag Trace flag
 * @param tags Tag of trace
 * @param limitSize Max size of trace file, in bytes, the max is 500MB.
 * @param fileName Output trace file name buffer
 * @param length Output trace file name buffer length
 * @return 0 - Success
 *         {@link HIDEBUG_INVALID_ARGUMENT} 401 - if the fileName is null or the length is too short or
 *         limitSize is too small
 *         11400102 - Have already capture trace
 *         11400103 - Have no permission to trace
 *         11400104 - The Possible reason is some error in the system.
 * @since 12
 */
HiDebug_ErrorCode OH_HiDebug_StartAppTraceCapture(HiDebug_TraceFlag flag,
    uint64_t tags, uint32_t limitSize, char* fileName, uint32_t length);

/**
 * @brief Stop capture application trace.
 *
 * @return 0 - Success
 *         11400104 - Maybe no trace is running or some error in the system.
 * @since 12
 */
HiDebug_ErrorCode OH_HiDebug_StopAppTraceCapture();

#ifdef __cplusplus
}
#endif // __cplusplus
/** @} */

#endif // HIVIEWDFX_HIDEBUG_H