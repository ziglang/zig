/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef HIVIEWDFX_HITRACE_H
#define HIVIEWDFX_HITRACE_H
/**
 * @addtogroup Hitrace
 * @{
 *
 * @brief hiTraceMeter provides APIs for system performance trace.
 *
 * You can call the APIs provided by hiTraceMeter in your own service logic to effectively
 * track service processes and check the system performance.
 *
 * @brief hitraceChain provides APIs for cross-thread and cross-process distributed tracing.
 * hiTraceChain generates a unique chain ID for a service process and passes it to various information (including
 * application events, system events, and logs) specific to the service process.
 * During debugging and fault locating, you can use the unique chain ID to quickly correlate various information related
 * to the service process.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 10
 */

/**
 * @file trace.h
 *
 * @kit PerformanceAnalysisKit
 *
 * @brief Defines APIs of the HiTraceMeter module for performance trace.
 *
 * Sample code: \n
 * Synchronous timeslice trace event: \n
 *     OH_HiTrace_StartTrace("hitraceTest");\n
 *     OH_HiTrace_FinishTrace();\n
 * Output: \n
 *     <...>-1668    (-------) [003] ....   135.059377: tracing_mark_write: B|1668|H:hitraceTest \n
 *     <...>-1668    (-------) [003] ....   135.059415: tracing_mark_write: E|1668| \n
 * Asynchronous timeslice trace event:\n
 *     OH_HiTrace_StartAsyncTrace("hitraceTest", 123); \n
 *     OH_HiTrace_FinishAsyncTrace("hitraceTest", 123); \n
 * Output: \n
 *     <...>-2477    (-------) [001] ....   396.427165: tracing_mark_write: S|2477|H:hitraceTest 123 \n
 *     <...>-2477    (-------) [001] ....   396.427196: tracing_mark_write: F|2477|H:hitraceTest 123 \n
 * Integer value trace event:\n
 *     OH_HiTrace_CountTrace("hitraceTest", 500); \n
 * Output: \n
 *     <...>-2638    (-------) [002] ....   458.904382: tracing_mark_write: C|2638|H:hitraceTest 500 \n
 *
 * @library libhitracechain.so
 * @syscap SystemCapability.HiviewDFX.HiTrace
 * @since 10
 */
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines whether a <b>HiTraceId</b> instance is valid.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
typedef enum HiTraceId_Valid {
    /**
     * @brief Invalid <b>HiTraceId</b> instance.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_ID_INVALID = 0,

    /**
     * @brief Valid <b>HiTraceId</b> instance.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_ID_VALID = 1,
} HiTraceId_Valid;

/**
 * @brief Enumerates the HiTrace version numbers.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
typedef enum HiTrace_Version {
    /**
     * @brief Version 1.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_VER_1 = 0,
} HiTrace_Version;

/**
 * @brief Enumerates the HiTrace flags.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
typedef enum HiTrace_Flag {
    /**
     * @brief Default flag.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_FLAG_DEFAULT = 0,

    /**
     * @brief Both synchronous and asynchronous calls are traced. By default, only synchronous calls are traced.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_FLAG_INCLUDE_ASYNC = 1 << 0,

    /**
     * @brief No spans are created. By default, spans are created.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_FLAG_DONOT_CREATE_SPAN = 1 << 1,

    /**
     * @brief Trace points are automatically added to spans. By default, no trace point is added.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_FLAG_TP_INFO = 1 << 2,

    /**
     * @brief Information about the start and end of the trace task is not printed. By default, information about the
     * start and end of the trace task is printed.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_FLAG_NO_BE_INFO = 1 << 3,

    /**
     * @brief The ID is not added to the log. By default, the ID is added to the log.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_FLAG_DONOT_ENABLE_LOG = 1 << 4,

    /**
     * @brief Tracing is triggered by faults.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_FLAG_FAULT_TRIGGER = 1 << 5,

    /**
     * @brief Trace points are added only for call chain trace between devices.
     * By default, device-to-device trace points are not added.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_FLAG_D2D_TP_INFO = 1 << 6,
} HiTrace_Flag;

/**
 * @brief Enumerates the HiTrace trace point types.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
typedef enum HiTrace_Tracepoint_Type {
    /**
     * @brief CS trace point.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_TP_CS = 0,
    /**
     * @brief CR trace point.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_TP_CR = 1,
    /**
     * @brief SS trace point.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_TP_SS = 2,
    /**
     * @brief SR trace point.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_TP_SR = 3,
    /**
     * @brief General trace point.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_TP_GENERAL = 4,
} HiTrace_Tracepoint_Type;

/**
 * @brief Enumerates the HiTrace communication modes.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
typedef enum HiTrace_Communication_Mode {
    /**
     * @brief Default communication mode.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_CM_DEFAULT = 0,
    /**
     * @brief Inter-thread communication.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_CM_THREAD = 1,
    /**
     * @brief Inter-process communication.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_CM_PROCESS = 2,
    /**
     * @brief Inter-device communication.
     *
     * @syscap SystemCapability.HiviewDFX.HiTrace
     *
     * @since 12
     */
    HITRACE_CM_DEVICE = 3,
} HiTrace_Communication_Mode;

/**
 * @brief Defines a <b>HiTraceId</b> instance.
 *
 * @struct HiTraceId
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
typedef struct HiTraceId {
#if __BYTE_ORDER == __LITTLE_ENDIAN
    /** Whether the <b>HiTraceId</b> instance is valid. */
    uint64_t valid : 1;
    /** Version number of the <b>HiTraceId</b> instance. */
    uint64_t ver : 3;
    /** Chain ID of the <b>HiTraceId</b> instance. */
    uint64_t chainId : 60;
    /** Flag of the <b>HiTraceId</b> instance. */
    uint64_t flags : 12;
    /** Span ID of the <b>HiTraceId</b> instance. */
    uint64_t spanId : 26;
    /** Parent span ID of the <b>HiTraceId</b> instance. */
    uint64_t parentSpanId : 26;
#elif __BYTE_ORDER == __BIG_ENDIAN
    /** Chain ID of the <b>HiTraceId</b> instance. */
    uint64_t chainId : 60;
    /** Version number of the <b>HiTraceId</b> instance. */
    uint64_t ver : 3;
    /** Whether the <b>HiTraceId</b> instance is valid. */
    uint64_t valid : 1;
    /** Parent span ID of the <b>HiTraceId</b> instance. */
    uint64_t parentSpanId : 26;
    /** Span ID of the <b>HiTraceId</b> instance. */
    uint64_t spanId : 26;
    /** Flag of the <b>HiTraceId</b> instance. */
    uint64_t flags : 12;
#else
#error "ERROR: No BIG_LITTLE_ENDIAN defines."
#endif
} HiTraceId;

/**
 * @brief Starts tracing of a process.
 *
 * This API starts tracing, creates a <b>HiTraceId</b> instance, and sets it to the TLS of the calling thread.
 * This API works only when it is called for the first time.
 *
 * @param name Pointer to a process name.
 * @param flags Trace flag.
 * @return Returns the created <b>HiTraceId</b> instance.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
HiTraceId OH_HiTrace_BeginChain(const char *name, int flags);

/**
 * @brief Ends tracing and clears the <b>HiTraceId</b> instance of the calling thread from the TLS.
 *
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_EndChain();

/**
 * @brief Obtains the trace ID of the calling thread from the TLS.
 *
 *
 * @return Returns the trace ID of the calling thread. If the calling thread does not have a trace ID,
 * an invalid trace ID is returned.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
HiTraceId OH_HiTrace_GetId();

/**
 * @brief Sets the trace ID of the calling thread. If the ID is invalid, no operation is performed.
 *
 * This API sets a <b>HiTraceId</b> instance to the TLS of the calling thread.
 *
 * @param id Trace ID to set.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_SetId(const HiTraceId *id);

/**
 * @brief Clears the trace ID of the calling thread and invalidates it.
 *
 * This API clears the <b>HiTraceId</b> instance in the TLS of the calling thread.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_ClearId(void);

/**
 * @brief Creates a span ID based on the trace ID of the calling thread.
 *
 * This API generates a new span and corresponding <b>HiTraceId</b> instance based on the <b>HiTraceId</b>
 * instance in the TLS of the calling thread.
 *
 * @return Returns a valid span ID. If span creation is not allowed, the ID of the calling thread is traced.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
HiTraceId OH_HiTrace_CreateSpan(void);

/**
 * @brief Prints HiTrace information, including the trace ID.
 *
 * This API prints trace point information, including the communication mode, trace point type, timestamp, and span.
 *
 * @param mode Communication mode for the trace point.
 * @param type Trace point type.
 * @param id Trace ID.
 * @param fmt Custom information to print.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_Tracepoint(
    HiTrace_Communication_Mode mode, HiTrace_Tracepoint_Type type, const HiTraceId *id, const char *fmt, ...);

/**
 * @brief Initializes a <b>HiTraceId</b> structure.
 *
 * @param id ID of the <b>HiTraceId</b> structure to be initialized.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_InitId(HiTraceId *id);

/**
 * @brief Creates a <b>HiTraceId</b> structure based on a byte array.
 *
 * @param id ID of the <b>HiTraceId</b> structure to be created.
 * @param pIdArray Byte array.
 * @param len Length of the byte array.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_IdFromBytes(HiTraceId *id, const uint8_t *pIdArray, int len);

/**
 * @brief Checks whether a <b>HiTraceId</b> instance is valid.
 *
 *
 * @param id <b>HiTraceId</b> instance to check.
 * @return Returns <b>true</b> if the <b>HiTraceId</b> instance is valid; returns <b>false</b> otherwise.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
bool OH_HiTrace_IsIdValid(const HiTraceId *id);

/**
 * @brief Checks whether the specified trace flag in a <b>HiTraceId</b> instance is enabled.
 *
 *
 * @param id <b>HiTraceId</b> instance to check.
 * @param flag Specified trace flag.
 * @return Returns <b>true</b> if the specified trace flag is enabled; returns <b>false</b> otherwise.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
bool OH_HiTrace_IsFlagEnabled(const HiTraceId *id, HiTrace_Flag flag);

/**
 * @brief Enables the specified trace flag in a <b>HiTraceId</b> instance.
 *
 *
 * @param id <b>HiTraceId</b> instance for which you want to enable the specified trace flag.
 * @param flag Specified trace flag.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_EnableFlag(const HiTraceId *id, HiTrace_Flag flag);

/**
 * @brief Obtains the trace flag set in a <b>HiTraceId</b> instance.
 *
 * @param id <b>HiTraceId</b> instance.
 *
 * @return Returns the trace flag set in the specified <b>HiTraceId</b> instance.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
int OH_HiTrace_GetFlags(const HiTraceId *id);

/**
 * @brief Sets the trace flag for a <b>HiTraceId</b> instance.
 *
 * @param id <b>HiTraceId</b> instance.
 * @param flags Trace flag to set.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_SetFlags(HiTraceId *id, int flags);

/**
 * @brief Obtains the trace chain ID.
 *
 * @param id <b>HiTraceId</b> instance for which you want to obtain the trace chain ID.
 *
 * @return Returns the trace chain ID of the specified <b>HiTraceId</b> instance.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
uint64_t OH_HiTrace_GetChainId(const HiTraceId *id);

/**
 * @brief Sets the trace chain ID to a <b>HiTraceId</b> instance
 *
 * @param id <b>HiTraceId</b> instance.
 * @param chainId Trace chain ID to set.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_SetChainId(HiTraceId *id, uint64_t chainId);

/**
 * @brief Obtains the span ID in a <b>HiTraceId</b> instance.
 *
 * @param id <b>HiTraceId</b> instance for which you want to obtain the span ID.
 *
 * @return Returns the span ID in the specified <b>HiTraceId</b> instance.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
uint64_t OH_HiTrace_GetSpanId(const HiTraceId *id);

/**
 * @brief Sets the span ID in a <b>HiTraceId</b> instance.
 *
 * @param id <b>HiTraceId</b> instance for which you want to set the span ID.
 * @param spanId Span ID to set.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_SetSpanId(HiTraceId *id, uint64_t spanId);

/**
 * @brief Obtains the parent span ID in a <b>HiTraceId</b> instance.
 *
 * @param id <b>HiTraceId</b> instance for which you want to obtain the parent span ID.
 *
 * @return Returns the parent span ID in the specified <b>HiTraceId</b> instance.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
uint64_t OH_HiTrace_GetParentSpanId(const HiTraceId *id);

/**
 * @brief Sets the parent span ID in a <b>HiTraceId</b> instance.
 *
 * @param id <b>HiTraceId</b> instance for which you want to set the parent span ID.
 * @param parentSpanId Parent span ID to set.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
void OH_HiTrace_SetParentSpanId(HiTraceId *id, uint64_t parentSpanId);

/**
 * @brief Converts a <b>HiTraceId</b> instance into a byte array for caching or communication.
 *
 * @param id <b>HiTraceId</b> instance to be converted.
 * @param pIdArray Byte array.
 * @param len Length of the byte array.
 *
 * @return Returns the length of the byte array after conversion.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 *
 * @since 12
 */
int OH_HiTrace_IdToBytes(const HiTraceId* id, uint8_t* pIdArray, int len);

/**
 * @brief Marks the start of a synchronous trace task.
 *
 * The <b>OH_HiTrace_StartTrace</b> and <b>OH_HiTrace_FinishTrace</b> APIs must be used in pairs.
 * The two APIs can be used in nested mode. The stack data structure is used for matching during trace data parsing.
 *
 * @param name Name of a trace task.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 * @since 10
 */
void OH_HiTrace_StartTrace(const char *name);

/**
 * @brief Marks the end of a synchronous trace task.
 *
 * This API must be used with <b>OH_HiTrace_StartTrace</b> in pairs. During trace data parsing, the system matches
 * it with the <b>OH_HiTrace_StartTrace</b> API recently invoked in the service process.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 * @since 10
 */
void OH_HiTrace_FinishTrace(void);

/**
 * @brief Marks the start of an asynchronous trace task.
 *
 * This API is called to implement performance trace in asynchronous manner. The start and end of an asynchronous
 * trace task do not occur in sequence. Therefore, a unique <b>taskId</b> is required to ensure proper data parsing.
 * It is passed as an input parameter for the asynchronous API.
 * This API is used with <b>OH_HiTrace_FinishAsyncTrace</b> in pairs. The two APIs that have the same name and
 * task ID together form an asynchronous timeslice trace task.
 * If multiple trace tasks with the same name need to be performed at the same time or a trace task needs to be
 * performed multiple times concurrently, different task IDs must be specified in <b>OH_HiTrace_StartTrace</b>.
 * If the trace tasks with the same name are not performed at the same time, the same taskId can be used.
 *
 * @param name Name of the asynchronous trace task.
 * @param taskId ID of the asynchronous trace task. The start and end of an asynchronous trace task do not occur in
 * sequence. Therefore, the start and end of an asynchronous trace need to be matched based on the task name and the
 * unique task ID together.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 * @since 10
 */
void OH_HiTrace_StartAsyncTrace(const char *name, int32_t taskId);

/**
 * @brief Marks the end of an asynchronous trace task.
 *
 * This API is called in the callback function after an asynchronous trace is complete.
 * It is used with <b>OH_HiTrace_StartAsyncTrace</b> in pairs. Its name and task ID must be the same as those of
 * <b>OH_HiTrace_StartAsyncTrace</b>.
 *
 * @param name Name of the asynchronous trace task.
 * @param taskId ID of the asynchronous trace task. The start and end of an asynchronous trace task do not occur in
 * sequence. Therefore, the start and end of an asynchronous trace need to be matched based on the task name and the
 * unique task ID together.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 * @since 10
 */
void OH_HiTrace_FinishAsyncTrace(const char *name, int32_t taskId);

/**
 * @brief Traces the value change of an integer variable based on its name.
 *
 * This API can be executed for multiple times to trace the value change of a given integer variable at different
 * time points.
 *
 * @param name Name of the integer variable. It does not need to be the same as the real variable name.
 * @param count Integer value. Generally, an integer variable can be passed.
 *
 * @syscap SystemCapability.HiviewDFX.HiTrace
 * @since 10
 */
void OH_HiTrace_CountTrace(const char *name, int64_t count);

#ifdef __cplusplus
}
#endif
#endif // HIVIEWDFX_HITRACE_H