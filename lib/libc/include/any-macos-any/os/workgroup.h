/*
 * Copyright (c) 2020 Apple Inc. All rights reserved.
 *
 * @APPLE_APACHE_LICENSE_HEADER_START@
 *
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
 *
 * @APPLE_APACHE_LICENSE_HEADER_END@
 */

#ifndef __OS_WORKGROUP__
#define __OS_WORKGROUP__

#ifndef __DISPATCH_BUILDING_DISPATCH__
#ifndef __OS_WORKGROUP_INDIRECT__
#define __OS_WORKGROUP_INDIRECT__
#endif /* __OS_WORKGROUP_INDIRECT__ */

#include <os/workgroup_base.h>
#include <os/workgroup_object.h>
#include <os/workgroup_interval.h>
#include <os/workgroup_parallel.h>

#undef __OS_WORKGROUP_INDIRECT__
#endif /* __DISPATCH_BUILDING_DISPATCH__ */

#endif /* __OS_WORKGROUP__ */