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

#ifndef	_FORTIFY_FORTIFY_H
#define	_FORTIFY_FORTIFY_H

#ifdef __cplusplus
extern "C" {
#endif

#if (_FORTIFY_SOURCE == 1) || (_FORTIFY_SOURCE == 2)
#ifndef __FORTIFY_COMPILATION
#define __FORTIFY_COMPILATION
#endif
#endif

#if (_FORTIFY_SOURCE == 2)
#ifndef __FORTIFY_RUNTIME
#define __FORTIFY_RUNTIME
#endif
#endif

#if defined(__cplusplus)
#define __DIAGNOSE_CAST(_k, _t, _v) (_k<_t>(_v))
#else
#define __DIAGNOSE_CAST(_k, _t, _v) ((_t) (_v))
#endif

#if defined(__LP64__)
#ifndef	FORTIFY_LONG_MAX
#define FORTIFY_LONG_MAX 0x7fffffffffffffffL
#endif
#ifndef	FORTIFY_SSIZE_MAX
#define FORTIFY_SSIZE_MAX FORTIFY_LONG_MAX
#endif
#else
#ifndef	FORTIFY_LONG_MAX
#define FORTIFY_LONG_MAX 0x7fffffffL
#endif
#ifndef	FORTIFY_SSIZE_MAX
#define FORTIFY_SSIZE_MAX FORTIFY_LONG_MAX
#endif
#endif
#ifndef	FORTIFY_PATH_MAX
#define FORTIFY_PATH_MAX 4096
#endif

#define __DIAGNOSE_ALWAYS_INLINE __attribute__((__always_inline__))
#define	__DIAGNOSE_PREDICT_TRUE(exp)	__builtin_expect((exp) != 0, 1)
#define	__DIAGNOSE_PREDICT_FALSE(exp)	__builtin_expect((exp) != 0, 0)
#define __DIAGNOSE_ENABLE_IF(cond, msg) __attribute__((enable_if(cond, msg)))
#define __DIAGNOSE_ERROR_IF(cond, msg) __attribute__((diagnose_if(cond, msg, "error")))
#define __DIAGNOSE_WARNING_IF(cond, msg) __attribute__((diagnose_if(cond, msg, "warning")))

#define __DIAGNOSE_BOS_LEVEL (1)
#define __DIAGNOSE_BOSN(s, n) __builtin_object_size((s), (n))
#define __DIAGNOSE_BOS(s) __DIAGNOSE_BOSN((s), __DIAGNOSE_BOS_LEVEL)

#define __DIAGNOSE_BOS0(s) __DIAGNOSE_BOSN((s), 0)
#define __DIAGNOSE_PASS_OBJECT_SIZE_N(n) __attribute__((pass_object_size(n)))
#define __DIAGNOSE__SIZE_MUL_OVERFLOW(a, b, result) __builtin_umull_overflow(a, b, result)
#define __DIAGNOSE_PRINTFLIKE(x, y) __attribute__((__format__(printf, x, y)))
#define __DIAGNOSE_CALL_BYPASSING_FORTIFY(fn) (&(fn))
#define __DIAGNOSE_FORTIFY_INLINE static __inline__ __attribute__((no_stack_protector)) \
    __DIAGNOSE_ALWAYS_INLINE

#define __DIAGNOSE_FORTIFY_VARIADIC static __inline__

#define __DIAGNOSE_PASS_OBJECT_SIZE __DIAGNOSE_PASS_OBJECT_SIZE_N(__DIAGNOSE_BOS_LEVEL)
#define __DIAGNOSE_PASS_OBJECT_SIZE0 __DIAGNOSE_PASS_OBJECT_SIZE_N(0)

#define __DIAGNOSE_FORTIFY_UNKNOWN_SIZE ((unsigned int) -1)
/* The following are intended for use in unevaluated environments, e.g. diagnose_if conditions. */
#define __DIAGNOSE_UNEVALUATED_LT(bos_val, val) \
((bos_val) != __DIAGNOSE_FORTIFY_UNKNOWN_SIZE && (bos_val) < (val))

#define __DIAGNOSE_UNEVALUATED_LE(bos_val, val) \
    ((bos_val) != __DIAGNOSE_FORTIFY_UNKNOWN_SIZE && (bos_val) <= (val))

/* The following acts in the context of evaluation. */
#define __DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL_AND(bos_val, op, index, cond) \
    ((bos_val) == __DIAGNOSE_FORTIFY_UNKNOWN_SIZE ||                 \
    (__builtin_constant_p(index) && bos_val op index && (cond)))

#define __DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL(bos_val, op, index) \
    __DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL_AND(bos_val, op, index, 1)

#define __DIAGNOSE_BOS_TRIVIALLY_GE(bos_val, index) __DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL((bos_val), >=, (index))
#define __DIAGNOSE_BOS_TRIVIALLY_GT(bos_val, index) __DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL((bos_val), >, (index))

#define __DIAGNOSE_OVERLOAD __attribute__((overloadable))

/*
 * A function to prevent this function from being applied.
 * Used to rename the function so that the compiler emits a call to "x".
 */
#define __DIAGNOSE_RENAME(x) __asm__(#x)
#define __DIAGNOSE_OPEN_MODES_USEFUL(flags) (((flags) & O_CREAT) || ((flags) & O_TMPFILE) == O_TMPFILE)
#define __DIAGNOSE_BOS_FD_COUNT_TRIVIALLY_SAFE(bos_val, fds, fd_count)              \
    __DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL_AND((bos_val), >=, (sizeof(*(fds)) * (fd_count)), \
    (fd_count) <= __DIAGNOSE_CAST(static_cast, unsigned int, -1) / sizeof(*(fds)))

#define __DIAGNOSE_UNSAFE_CHK_MUL_OVERFLOW(x, y) ((__SIZE_TYPE__)-1 / (x) < (y))

#define __DIAGNOSE_BOS_TRIVIALLY_GE_MUL(bos_val, size, count) \
    __DIAGNOSE_BOS_DYNAMIC_CHECK_IMPL_AND(bos_val, >=, (size) * (count), \
    !__DIAGNOSE_UNSAFE_CHK_MUL_OVERFLOW(size, count))

#define FORTIFY_RUNTIME_ERROR_PREFIX "Musl Fortify runtime error: "
#define OPEN_TOO_MANY_ARGS_ERROR "There are too many arguments"
#define OPEN_TOO_FEW_ARGS_ERROR "invoking with O_CREAT or O_TMPFILE, but missing pattern."
#define OPEN_USELESS_MODES_WARNING "having redundant mode bits; but missing O_CREAT."
#define CALLED_WITH_STRING_BIGGER_BUFFER "called with a string larger than the buffer"
#define FD_COUNT_LARGE_GIVEN_BUFFER "fd_count is greater than the given buffer"
#define CALLED_WITH_SIZE_BIGGER_BUFFER "called with bigger size than the buffer"
#define OUTPUT_PARAMETER_BYTES "the output parameter must be nullptr or a pointer to the buffer with >= FORTIFY_PATH_MAX bytes"
#define SIZE_LARGER_THEN_DESTINATION_BUFFER "the size is greater than the target buffer"

void __fortify_error(const char* info, ...);

#ifdef __cplusplus
}
#endif

#endif