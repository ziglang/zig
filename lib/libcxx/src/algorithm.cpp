//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include <algorithm>

_LIBCPP_BEGIN_NAMESPACE_STD

// TODO(varconst): this currently doesn't benefit `ranges::sort` because it uses `ranges::less` instead of `__less`.

template void __sort<__less<char>&, char*>(char*, char*, __less<char>&);
#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template void __sort<__less<wchar_t>&, wchar_t*>(wchar_t*, wchar_t*, __less<wchar_t>&);
#endif
template void __sort<__less<signed char>&, signed char*>(signed char*, signed char*, __less<signed char>&);
template void __sort<__less<unsigned char>&, unsigned char*>(unsigned char*, unsigned char*, __less<unsigned char>&);
template void __sort<__less<short>&, short*>(short*, short*, __less<short>&);
template void __sort<__less<unsigned short>&, unsigned short*>(unsigned short*, unsigned short*, __less<unsigned short>&);
template void __sort<__less<int>&, int*>(int*, int*, __less<int>&);
template void __sort<__less<unsigned>&, unsigned*>(unsigned*, unsigned*, __less<unsigned>&);
template void __sort<__less<long>&, long*>(long*, long*, __less<long>&);
template void __sort<__less<unsigned long>&, unsigned long*>(unsigned long*, unsigned long*, __less<unsigned long>&);
template void __sort<__less<long long>&, long long*>(long long*, long long*, __less<long long>&);
template void __sort<__less<unsigned long long>&, unsigned long long*>(unsigned long long*, unsigned long long*, __less<unsigned long long>&);
template void __sort<__less<float>&, float*>(float*, float*, __less<float>&);
template void __sort<__less<double>&, double*>(double*, double*, __less<double>&);
template void __sort<__less<long double>&, long double*>(long double*, long double*, __less<long double>&);

template bool __insertion_sort_incomplete<__less<char>&, char*>(char*, char*, __less<char>&);
#ifndef _LIBCPP_HAS_NO_WIDE_CHARACTERS
template bool __insertion_sort_incomplete<__less<wchar_t>&, wchar_t*>(wchar_t*, wchar_t*, __less<wchar_t>&);
#endif
template bool __insertion_sort_incomplete<__less<signed char>&, signed char*>(signed char*, signed char*, __less<signed char>&);
template bool __insertion_sort_incomplete<__less<unsigned char>&, unsigned char*>(unsigned char*, unsigned char*, __less<unsigned char>&);
template bool __insertion_sort_incomplete<__less<short>&, short*>(short*, short*, __less<short>&);
template bool __insertion_sort_incomplete<__less<unsigned short>&, unsigned short*>(unsigned short*, unsigned short*, __less<unsigned short>&);
template bool __insertion_sort_incomplete<__less<int>&, int*>(int*, int*, __less<int>&);
template bool __insertion_sort_incomplete<__less<unsigned>&, unsigned*>(unsigned*, unsigned*, __less<unsigned>&);
template bool __insertion_sort_incomplete<__less<long>&, long*>(long*, long*, __less<long>&);
template bool __insertion_sort_incomplete<__less<unsigned long>&, unsigned long*>(unsigned long*, unsigned long*, __less<unsigned long>&);
template bool __insertion_sort_incomplete<__less<long long>&, long long*>(long long*, long long*, __less<long long>&);
template bool __insertion_sort_incomplete<__less<unsigned long long>&, unsigned long long*>(unsigned long long*, unsigned long long*, __less<unsigned long long>&);
template bool __insertion_sort_incomplete<__less<float>&, float*>(float*, float*, __less<float>&);
template bool __insertion_sort_incomplete<__less<double>&, double*>(double*, double*, __less<double>&);
template bool __insertion_sort_incomplete<__less<long double>&, long double*>(long double*, long double*, __less<long double>&);

template unsigned __sort5<__less<long double>&, long double*>(long double*, long double*, long double*, long double*, long double*, __less<long double>&);

_LIBCPP_END_NAMESPACE_STD
