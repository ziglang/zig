/*
 * Copyright (c) 2021-2022 Huawei Device Co., Ltd.
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

#ifndef HIVIEWDFX_HILOG_H
#define HIVIEWDFX_HILOG_H
/**
 * @addtogroup HiLog
 * @{
 *
 * @brief Provides logging functions.
 *
 * For example, you can use these functions to output logs of the specified log type, service domain, log tag,
 * and log level.
 *
 * @syscap SystemCapability.HiviewDFX.HiLog
 *
 * @since 8
 */

/**
 * @file log.h
 *
 * @brief Defines the logging functions of the HiLog module.
 *
 * Before outputting logs, you must define the service domain, and log tag, use the function with
 * the specified log type and level, and specify the privacy identifier.\n
 * <ul><li>Service domain: used to identify the subsystem and module of a service. Its value is a hexadecimal
 * integer ranging from 0x0 to 0xFFFF. \n
 * <li>Log tag: a string used to identify the class, file, or service.</li> \n
 * <li>Log level: <b>DEBUG</b>, <b>INFO</b>, <b>WARN</b>, <b>ERROR</b>, and <b>FATAL</b></li> \n
 * <li>Parameter format: a printf format string that starts with a % character, including format specifiers
 * and variable parameters.</li> \n
 * <li>Privacy identifier: {public} or {private} added between the % character and the format specifier in
 * each parameter. Note that each parameter has a privacy identifier. If no privacy identifier is added,
 * the parameter is considered to be <b>private</b>.</li></ul> \n
 *
 * Sample code:\n
 * Defining the service domain and log tag:\n
 *     #include <hilog/log.h>\n
 *     #define LOG_DOMAIN 0x0201\n
 *     #define LOG_TAG "MY_TAG"\n
 * Outputting logs:\n
 *     HILOG_WARN({@link LOG_APP}, "Failed to visit %{private}s, reason:%{public}d.", url, errno);\n
 * Output result:\n
 *     05-06 15:01:06.870 1051 1051 W 0201/MY_TAG: Failed to visit <private>, reason:503.\n
 *
 * @since 8
 */
#include <stdarg.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the service domain for a log file.
 *
 * The service domain is used to identify the subsystem and module of a service. Its value is a hexadecimal integer
 * ranging from 0x0 to 0xFFFF. If the value is beyond the range, its significant bits are automatically truncated. \n
 *
 * @since 8
 */
#ifndef LOG_DOMAIN
#define LOG_DOMAIN 0
#endif

/**
 * @brief Defines a string constant used to identify the class, file, or service.
 *
 * @since 8
 */
#ifndef LOG_TAG
#define LOG_TAG NULL
#endif

/**
 * @brief Enumerates log types.
 *
 * Currently, <b>LOG_APP</b> is available. \n
 *
 * @since 8
 */
typedef enum {
    /** Third-party application logs */
    LOG_APP = 0,
} LogType;

/**
 * @brief Enumerates log levels.
 *
 * You are advised to select log levels based on their respective usage scenarios:\n
 * <ul><li><b>DEBUG</b>: used for debugging and disabled from commercial releases</li> \n
 * <li><b>INFO</b>: used for logging important system running status and steps in key processes</li> \n
 * <li><b>WARN</b>: used for logging unexpected exceptions that have little impact on user experience and can
 * automatically recover. Logs at this level are generally output when such exceptions are detected and
 * captured.</li> \n
 * <li><b>ERROR</b>: used for logging malfunction that affects user experience and cannot automatically
 * recover</li>\n
 * <li><b>FATAL</b>: used for logging major exceptions that have severely affected user experience and should
 * not occur.</li></ul> \n
 *
 * @since 8
 */
typedef enum {
    /** Debug level to be used by {@link OH_LOG_DEBUG} */
    LOG_DEBUG = 3,
    /** Informational level to be used by {@link OH_LOG_INFO} */
    LOG_INFO = 4,
    /** Warning level to be used by {@link OH_LOG_WARN} */
    LOG_WARN = 5,
    /** Error level to be used by {@link OH_LOG_ERROR} */
    LOG_ERROR = 6,
    /** Fatal level to be used by {@link OH_LOG_FATAL} */
    LOG_FATAL = 7,
} LogLevel;

/**
 * @brief Outputs logs.
 *
 * You can use this function to output logs based on the specified log type, log level, service domain, log tag,
 * and variable parameters determined by the format specifier and privacy identifier in the printf format.
 *
 * @param type Indicates the log type. The type for third-party applications is defined by {@link LOG_APP}.
 * @param level Indicates the log level, which can be <b>LOG_DEBUG</b>, <b>LOG_INFO</b>, <b>LOG_WARN</b>,
 * <b>LOG_ERROR</b>, and <b>LOG_FATAL</b>.
 * @param domain Indicates the service domain of logs. Its value is a hexadecimal integer ranging from 0x0 to 0xFFFF.
 * @param tag Indicates the log tag, which is a string used to identify the class, file, or service behavior.
 * @param fmt Indicates the format string, which is an enhancement of a printf format string and supports the privacy
 * identifier. Specifically, {public} or {private} is added between the % character and the format specifier
 * in each parameter. \n
 * @param ... Indicates a list of parameters. The number and type of parameters must map onto the format specifiers
 * in the format string.
 * @return Returns <b>0</b> or a larger value if the operation is successful; returns a value smaller
 * than <b>0</b> otherwise.
 * @since 8
 */
int OH_LOG_Print(LogType type, LogLevel level, unsigned int domain, const char *tag, const char *fmt, ...)
    __attribute__((__format__(os_log, 5, 6)));

/**
 * @brief Checks whether logs of the specified service domain, log tag, and log level can be output.
 *
 * @param domain Indicates the service domain of logs.
 * @param tag Indicates the log tag.
 * @param level Indicates the log level.
 * @return Returns <b>true</b> if the specified logs can be output; returns <b>false</b> otherwise.
 * @since 8
 */
bool OH_LOG_IsLoggable(unsigned int domain, const char *tag, LogLevel level);

/**
 * @brief Outputs debug logs. This is a function-like macro.
 *
 * Before calling this function, define the log service domain and log tag. Generally, you need to define them at
 * the beginning of the source file. \n
 *
 * @param type Indicates the log type. The type for third-party applications is defined by {@link LOG_APP}.
 * @param fmt Indicates the format string, which is an enhancement of a printf format string and supports the
 * privacy identifier. Specifically, {public} or {private} is added between the % character and the format specifier
 * in each parameter. \n
 * @param ... Indicates a list of parameters. The number and type of parameters must map onto the format specifiers
 * in the format string.
 * @see OH_LOG_Print
 * @since 8
 */
#define OH_LOG_DEBUG(type, ...) ((void)OH_LOG_Print((type), LOG_DEBUG, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))

/**
 * @brief Outputs informational logs. This is a function-like macro.
 *
 * Before calling this function, define the log service domain and log tag. Generally, you need to define them
 * at the beginning of the source file. \n
 *
 * @param type Indicates the log type. The type for third-party applications is defined by {@link LOG_APP}.
 * @param fmt Indicates the format string, which is an enhancement of a printf format string and supports the privacy
 * identifier. Specifically, {public} or {private} is added between the % character and the format specifier in
 * each parameter. \n
 * @param ... Indicates a list of parameters. The number and type of parameters must map onto the format specifiers
 * in the format string.
 * @see OH_LOG_Print
 * @since 8
 */
#define OH_LOG_INFO(type, ...) ((void)OH_LOG_Print((type), LOG_INFO, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))

/**
 * @brief Outputs warning logs. This is a function-like macro.
 *
 * Before calling this function, define the log service domain and log tag. Generally, you need to define them
 * at the beginning of the source file. \n
 *
 * @param type Indicates the log type. The type for third-party applications is defined by {@link LOG_APP}.
 * @param fmt Indicates the format string, which is an enhancement of a printf format string and supports the
 * privacy identifier. Specifically, {public} or {private} is added between the % character and the format specifier
 * in each parameter. \n
 * @param ... Indicates a list of parameters. The number and type of parameters must map onto the format specifiers
 * in the format string.
 * @see OH_LOG_Print
 * @since 8
 */
#define OH_LOG_WARN(type, ...) ((void)OH_LOG_Print((type), LOG_WARN, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))

/**
 * @brief Outputs error logs. This is a function-like macro.
 *
 * Before calling this function, define the log service domain and log tag. Generally, you need to define
 * them at the beginning of the source file. \n
 *
 * @param type Indicates the log type. The type for third-party applications is defined by {@link LOG_APP}.
 * @param fmt Indicates the format string, which is an enhancement of a printf format string and supports the privacy
 * identifier. Specifically, {public} or {private} is added between the % character and the format specifier in each
 * parameter. \n
 * @param ... Indicates a list of parameters. The number and type of parameters must map onto the format specifiers
 * in the format string.
 * @see OH_LOG_Print
 * @since 8
 */
#define OH_LOG_ERROR(type, ...) ((void)OH_LOG_Print((type), LOG_ERROR, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))

/**
 * @brief Outputs fatal logs. This is a function-like macro.
 *
 * Before calling this function, define the log service domain and log tag. Generally, you need to define them at
 * the beginning of the source file. \n
 *
 * @param type Indicates the log type. The type for third-party applications is defined by {@link LOG_APP}.
 * @param fmt Indicates the format string, which is an enhancement of a printf format string and supports the privacy
 * identifier. Specifically, {public} or {private} is added between the % character and the format specifier in
 * each parameter. \n
 * @param ... Indicates a list of parameters. The number and type of parameters must map onto the format specifiers
 * in the format string.
 * @see OH_LOG_Print
 * @since 8
 */
#define OH_LOG_FATAL(type, ...) ((void)OH_LOG_Print((type), LOG_FATAL, LOG_DOMAIN, LOG_TAG, __VA_ARGS__))

/**
 * @brief Defines the function pointer type for the user-defined log processing function.
 *
 * @param type Indicates the log type. The type for third-party applications is defined by {@link LOG_APP}.
 * @param level Indicates the log level, which can be <b>LOG_DEBUG</b>, <b>LOG_INFO</b>, <b>LOG_WARN</b>,
 * <b>LOG_ERROR</b>, and <b>LOG_FATAL</b>.
 * @param domain Indicates the service domain of logs. Its value is a hexadecimal integer ranging from 0x0 to 0xFFFF.
 * @param tag Indicates the log tag, which is a string used to identify the class, file, or service behavior.
 * @param msg Indicates the log message itself, which is a formatted log string.
 * @since 11
 */
typedef void (*LogCallback)(const LogType type, const LogLevel level, const unsigned int domain, const char *tag,
    const char *msg);

/**
 * @brief Set the user-defined log processing function.
 *
 * After calling this function, the callback function implemented by the user can receive all hilogs of the
 * current process.
 * Note that it will not change the default behavior of hilog logs of the current process, no matter whether this
 * interface is called or not. \n
 *
 * @param callback Indicates the callback function implemented by the user. If you do not need to process hilog logs,
 * you can transfer a null pointer.
 * @since 11
 */
void OH_LOG_SetCallback(LogCallback callback);

#ifdef __cplusplus
}
#endif
/** @} */

#ifdef HILOG_RAWFORMAT
#include "hilog/log_inner.h"
#endif

#endif  // HIVIEWDFX_HILOG_C_H