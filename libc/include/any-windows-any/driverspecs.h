/*
 * PROJECT:         ReactOS DDK
 * COPYRIGHT:       This file is in the Public Domain.
 * FILE:            driverspecs.h
 * ABSTRACT:        This header stubs out Driver Verifier annotations to
 *                  allow drivers using them to compile with our header set.
 */

/*
 * Stubs
 */
#define __drv_dispatchType(x)
#define __drv_dispatchType_other

#define __drv_aliasesMem
#define __drv_allocatesMem(kind)
#define __drv_freesMem(kind)
