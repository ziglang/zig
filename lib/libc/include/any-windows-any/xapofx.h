/*
 * Copyright (c) 2015 Andrew Eikum for CodeWeavers
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

/* CLSIDs used by CreateFX, but never registered */

#ifndef _XAPOFX_H
#define _XAPOFX_H

/* xapofx 1.0 through 1.5 */
DEFINE_GUID(CLSID_FXEQ27, 0xa90bc001, 0xe897, 0xe897, 0x74, 0x39, 0x43, 0x55, 0x00, 0x00, 0x00, 0x00);
/* xaudio >= 2.8 */
DEFINE_GUID(CLSID_FXEQ, 0xf5e01117, 0xd6c4, 0x485a, 0xa3, 0xf5, 0x69, 0x51, 0x96, 0xf3, 0xdb, 0xfa);

/* xapofx 1.0 through 1.5 */
DEFINE_GUID(CLSID_FXMasteringLimiter27, 0xa90bc001, 0xe897, 0xe897, 0x74, 0x39, 0x43, 0x55, 0x00, 0x00, 0x00, 0x01);
/* xaudio >= 2.8 */
DEFINE_GUID(CLSID_FXMasteringLimiter, 0xc4137916, 0x2be1, 0x46fd, 0x85, 0x99, 0x44, 0x15, 0x36, 0xf4, 0x98, 0x56);

/* xapofx 1.0 through 1.5 */
DEFINE_GUID(CLSID_FXReverb27, 0xa90bc001, 0xe897, 0xe897, 0x74, 0x39, 0x43, 0x55, 0x00, 0x00, 0x00, 0x02);
/* xaudio >= 2.8 */
DEFINE_GUID(CLSID_FXReverb, 0x7d9aca56, 0xcb68, 0x4807, 0xb6, 0x32, 0xb1, 0x37, 0x35, 0x2e, 0x85, 0x96);

/* xapofx 1.0 through 1.5 */
DEFINE_GUID(CLSID_FXEcho27, 0xa90bc001, 0xe897, 0xe897, 0x74, 0x39, 0x43, 0x55, 0x00, 0x00, 0x00, 0x03);
/* xaudio >= 2.8 */
DEFINE_GUID(CLSID_FXEcho, 0x5039d740, 0xf736, 0x449a, 0x84, 0xd3, 0xa5, 0x62, 0x02, 0x55, 0x7b, 0x87);

#endif
