/*
 * Copyright (C) 2002 Alexandre Julliard
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __DMO_H__
#define __DMO_H__

#include <mediaerr.h>

#ifdef FIX_LOCK_NAME
#define Lock DMOLock
#endif
#include <mediaobj.h>
#ifdef FIX_LOCK_NAME
#undef Lock
#endif
#include <dmoreg.h>
#include <dmort.h>

#endif  /* __DMO_H__ */
