/*
 * PROJECT:         ReactOS DDK
 * COPYRIGHT:       This file is in the Public Domain.
 * FILE:            driverspecs.h
 * ABSTRACT:        This header stubs out Driver Verifier annotations to
 *                  allow drivers using them to compile with our header set.
 */

#ifndef DRIVERSPECS_H
#define DRIVERSPECS_H

#include <specstrings.h>

#define __drv_dispatchType(x)
#define __drv_dispatchType_other

#define __drv_aliasesMem
#define __drv_allocatesMem(kind)
#define __drv_freesMem(kind)

#define __drv_arg(x,y)
#define __drv_at(x,y)
#define __drv_deref(x)
#define __drv_in(x)
#define __drv_in_deref(x)
#define __drv_out(x)
#define __drv_out_deref(x)
#define __drv_when(x,y)

#define __internal_kernel_driver
#define __kernel_code
#define __kernel_driver
#define __user_code
#define __user_driver

#endif
