/*
 * Copyright (C) 2009 Damjan Jovanovic
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


#ifdef __WINESRC__
#error Specify wia_lh.h or wia_xp.h explicitly in Wine
#endif

#if (_WIN32_WINNT >= 0x0600)
#include <wia_lh.h>
#elif (_WIN32_WINNT >= 0x0501)
#include <wia_xp.h>
#endif
