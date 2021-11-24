/*
 * Copyright (c) 2019 by Apple Inc.. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
 
#ifndef __AVAILABILITY_VERSIONS__
#define __AVAILABILITY_VERSIONS__

#define __MAC_10_0            1000
#define __MAC_10_1            1010
#define __MAC_10_2            1020
#define __MAC_10_3            1030
#define __MAC_10_4            1040
#define __MAC_10_5            1050
#define __MAC_10_6            1060
#define __MAC_10_7            1070
#define __MAC_10_8            1080
#define __MAC_10_9            1090
#define __MAC_10_10         101000
#define __MAC_10_10_2       101002
#define __MAC_10_10_3       101003
#define __MAC_10_11         101100
#define __MAC_10_11_2       101102
#define __MAC_10_11_3       101103
#define __MAC_10_11_4       101104
#define __MAC_10_12         101200
#define __MAC_10_12_1       101201
#define __MAC_10_12_2       101202
#define __MAC_10_12_4       101204
#define __MAC_10_13         101300
#define __MAC_10_13_1       101301
#define __MAC_10_13_2       101302
#define __MAC_10_13_4       101304
#define __MAC_10_14         101400
#define __MAC_10_14_1       101401
#define __MAC_10_14_4       101404
#define __MAC_10_14_6       101406
#define __MAC_10_15         101500
#define __MAC_10_15_1       101501
#define __MAC_10_15_4       101504
#define __MAC_10_16         101600
#define __MAC_11_0          110000
#define __MAC_11_1          110100
/* __MAC_NA is not defined to a value but is used as a token by macros to indicate that the API is unavailable */

#define __IPHONE_2_0      20000
#define __IPHONE_2_1      20100
#define __IPHONE_2_2      20200
#define __IPHONE_3_0      30000
#define __IPHONE_3_1      30100
#define __IPHONE_3_2      30200
#define __IPHONE_4_0      40000
#define __IPHONE_4_1      40100
#define __IPHONE_4_2      40200
#define __IPHONE_4_3      40300
#define __IPHONE_5_0      50000
#define __IPHONE_5_1      50100
#define __IPHONE_6_0      60000
#define __IPHONE_6_1      60100
#define __IPHONE_7_0      70000
#define __IPHONE_7_1      70100
#define __IPHONE_8_0      80000
#define __IPHONE_8_1      80100
#define __IPHONE_8_2      80200
#define __IPHONE_8_3      80300
#define __IPHONE_8_4      80400
#define __IPHONE_9_0      90000
#define __IPHONE_9_1      90100
#define __IPHONE_9_2      90200
#define __IPHONE_9_3      90300
#define __IPHONE_10_0    100000
#define __IPHONE_10_1    100100
#define __IPHONE_10_2    100200
#define __IPHONE_10_3    100300
#define __IPHONE_11_0    110000
#define __IPHONE_11_1    110100
#define __IPHONE_11_2    110200
#define __IPHONE_11_3    110300
#define __IPHONE_11_4    110400
#define __IPHONE_12_0    120000
#define __IPHONE_12_1    120100
#define __IPHONE_12_2    120200
#define __IPHONE_12_3    120300
#define __IPHONE_12_4    120400
#define __IPHONE_13_0    130000
#define __IPHONE_13_1    130100
#define __IPHONE_13_2    130200
#define __IPHONE_13_3    130300
#define __IPHONE_13_4    130400
#define __IPHONE_13_5    130500
#define __IPHONE_13_6    130600
#define __IPHONE_13_7    130700
#define __IPHONE_14_0    140000
#define __IPHONE_14_1    140100
#define __IPHONE_14_2    140200
#define __IPHONE_14_3    140300
/* __IPHONE_NA is not defined to a value but is used as a token by macros to indicate that the API is unavailable */

#define __TVOS_9_0        90000
#define __TVOS_9_1        90100
#define __TVOS_9_2        90200
#define __TVOS_10_0      100000
#define __TVOS_10_0_1    100001
#define __TVOS_10_1      100100
#define __TVOS_10_2      100200
#define __TVOS_11_0      110000
#define __TVOS_11_1      110100
#define __TVOS_11_2      110200
#define __TVOS_11_3      110300
#define __TVOS_11_4      110400
#define __TVOS_12_0      120000
#define __TVOS_12_1      120100
#define __TVOS_12_2      120200
#define __TVOS_12_3      120300
#define __TVOS_12_4      120400
#define __TVOS_13_0      130000
#define __TVOS_13_2      130200
#define __TVOS_13_3      130300
#define __TVOS_13_4      130400
#define __TVOS_14_0      140000
#define __TVOS_14_1      140100
#define __TVOS_14_2      140200
#define __TVOS_14_3      140300

#define __WATCHOS_1_0     10000
#define __WATCHOS_2_0     20000
#define __WATCHOS_2_1     20100
#define __WATCHOS_2_2     20200
#define __WATCHOS_3_0     30000
#define __WATCHOS_3_1     30100
#define __WATCHOS_3_1_1   30101
#define __WATCHOS_3_2     30200
#define __WATCHOS_4_0     40000
#define __WATCHOS_4_1     40100
#define __WATCHOS_4_2     40200
#define __WATCHOS_4_3     40300
#define __WATCHOS_5_0     50000
#define __WATCHOS_5_1     50100
#define __WATCHOS_5_2     50200
#define __WATCHOS_5_3     50300
#define __WATCHOS_6_0     60000
#define __WATCHOS_6_1     60100
#define __WATCHOS_6_2     60200
#define __WATCHOS_7_0     70000
#define __WATCHOS_7_1     70100
#define __WATCHOS_7_2     70200

/*
 * Set up standard Mac OS X versions
 */

#if (!defined(_POSIX_C_SOURCE) && !defined(_XOPEN_SOURCE)) || defined(_DARWIN_C_SOURCE)

#define MAC_OS_X_VERSION_10_0         1000
#define MAC_OS_X_VERSION_10_1         1010
#define MAC_OS_X_VERSION_10_2         1020
#define MAC_OS_X_VERSION_10_3         1030
#define MAC_OS_X_VERSION_10_4         1040
#define MAC_OS_X_VERSION_10_5         1050
#define MAC_OS_X_VERSION_10_6         1060
#define MAC_OS_X_VERSION_10_7         1070
#define MAC_OS_X_VERSION_10_8         1080
#define MAC_OS_X_VERSION_10_9         1090
#define MAC_OS_X_VERSION_10_10      101000
#define MAC_OS_X_VERSION_10_10_2    101002
#define MAC_OS_X_VERSION_10_10_3    101003
#define MAC_OS_X_VERSION_10_11      101100
#define MAC_OS_X_VERSION_10_11_2    101102
#define MAC_OS_X_VERSION_10_11_3    101103
#define MAC_OS_X_VERSION_10_11_4    101104
#define MAC_OS_X_VERSION_10_12      101200
#define MAC_OS_X_VERSION_10_12_1    101201
#define MAC_OS_X_VERSION_10_12_2    101202
#define MAC_OS_X_VERSION_10_12_4    101204
#define MAC_OS_X_VERSION_10_13      101300
#define MAC_OS_X_VERSION_10_13_1    101301
#define MAC_OS_X_VERSION_10_13_2    101302
#define MAC_OS_X_VERSION_10_13_4    101304
#define MAC_OS_X_VERSION_10_14      101400
#define MAC_OS_X_VERSION_10_14_1    101401
#define MAC_OS_X_VERSION_10_14_4    101404
#define MAC_OS_X_VERSION_10_14_6    101406
#define MAC_OS_X_VERSION_10_15      101500
#define MAC_OS_X_VERSION_10_15_1    101501
#define MAC_OS_X_VERSION_10_16      101600
#define MAC_OS_VERSION_11_0         110000

#endif /* #if (!defined(_POSIX_C_SOURCE) && !defined(_XOPEN_SOURCE)) || defined(_DARWIN_C_SOURCE) */

#define __DRIVERKIT_19_0 190000
#define __DRIVERKIT_20_0 200000

#endif /* __AVAILABILITY_VERSIONS__ */