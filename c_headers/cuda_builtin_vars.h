/*===---- cuda_builtin_vars.h - CUDA built-in variables ---------------------===
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *===-----------------------------------------------------------------------===
 */

#ifndef __CUDA_BUILTIN_VARS_H
#define __CUDA_BUILTIN_VARS_H

// The file implements built-in CUDA variables using __declspec(property).
// https://msdn.microsoft.com/en-us/library/yhfk0thd.aspx
// All read accesses of built-in variable fields get converted into calls to a
// getter function which in turn would call appropriate builtin to fetch the
// value.
//
// Example:
//    int x = threadIdx.x;
// IR output:
//  %0 = call i32 @llvm.ptx.read.tid.x() #3
// PTX output:
//  mov.u32     %r2, %tid.x;

#define __CUDA_DEVICE_BUILTIN(FIELD, INTRINSIC)                                \
  __declspec(property(get = __fetch_builtin_##FIELD)) unsigned int FIELD;      \
  static inline __attribute__((always_inline))                                 \
      __attribute__((device)) unsigned int __fetch_builtin_##FIELD(void) {     \
    return INTRINSIC;                                                          \
  }

#if __cplusplus >= 201103L
#define __DELETE =delete
#else
#define __DELETE
#endif

// Make sure nobody can create instances of the special varible types.  nvcc
// also disallows taking address of special variables, so we disable address-of
// operator as well.
#define __CUDA_DISALLOW_BUILTINVAR_ACCESS(TypeName)                            \
  __attribute__((device)) TypeName() __DELETE;                                 \
  __attribute__((device)) TypeName(const TypeName &) __DELETE;                 \
  __attribute__((device)) void operator=(const TypeName &) const __DELETE;     \
  __attribute__((device)) TypeName *operator&() const __DELETE

struct __cuda_builtin_threadIdx_t {
  __CUDA_DEVICE_BUILTIN(x,__builtin_ptx_read_tid_x());
  __CUDA_DEVICE_BUILTIN(y,__builtin_ptx_read_tid_y());
  __CUDA_DEVICE_BUILTIN(z,__builtin_ptx_read_tid_z());
private:
  __CUDA_DISALLOW_BUILTINVAR_ACCESS(__cuda_builtin_threadIdx_t);
};

struct __cuda_builtin_blockIdx_t {
  __CUDA_DEVICE_BUILTIN(x,__builtin_ptx_read_ctaid_x());
  __CUDA_DEVICE_BUILTIN(y,__builtin_ptx_read_ctaid_y());
  __CUDA_DEVICE_BUILTIN(z,__builtin_ptx_read_ctaid_z());
private:
  __CUDA_DISALLOW_BUILTINVAR_ACCESS(__cuda_builtin_blockIdx_t);
};

struct __cuda_builtin_blockDim_t {
  __CUDA_DEVICE_BUILTIN(x,__builtin_ptx_read_ntid_x());
  __CUDA_DEVICE_BUILTIN(y,__builtin_ptx_read_ntid_y());
  __CUDA_DEVICE_BUILTIN(z,__builtin_ptx_read_ntid_z());
private:
  __CUDA_DISALLOW_BUILTINVAR_ACCESS(__cuda_builtin_blockDim_t);
};

struct __cuda_builtin_gridDim_t {
  __CUDA_DEVICE_BUILTIN(x,__builtin_ptx_read_nctaid_x());
  __CUDA_DEVICE_BUILTIN(y,__builtin_ptx_read_nctaid_y());
  __CUDA_DEVICE_BUILTIN(z,__builtin_ptx_read_nctaid_z());
private:
  __CUDA_DISALLOW_BUILTINVAR_ACCESS(__cuda_builtin_gridDim_t);
};

#define __CUDA_BUILTIN_VAR                                                     \
  extern const __attribute__((device)) __attribute__((weak))
__CUDA_BUILTIN_VAR __cuda_builtin_threadIdx_t threadIdx;
__CUDA_BUILTIN_VAR __cuda_builtin_blockIdx_t blockIdx;
__CUDA_BUILTIN_VAR __cuda_builtin_blockDim_t blockDim;
__CUDA_BUILTIN_VAR __cuda_builtin_gridDim_t gridDim;

// warpSize should translate to read of %WARP_SZ but there's currently no
// builtin to do so. According to PTX v4.2 docs 'to date, all target
// architectures have a WARP_SZ value of 32'.
__attribute__((device)) const int warpSize = 32;

#undef __CUDA_DEVICE_BUILTIN
#undef __CUDA_BUILTIN_VAR
#undef __CUDA_DISALLOW_BUILTINVAR_ACCESS

#endif /* __CUDA_BUILTIN_VARS_H */
