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

#ifndef __AUDEVCOD__
#define __AUDEVCOD__

typedef enum _tagSND_DEVICE_ERROR
{
    SNDDEV_ERROR_Open=1,
    SNDDEV_ERROR_Close=2,
    SNDDEV_ERROR_GetCaps=3,
    SNDDEV_ERROR_PrepareHeader=4,
    SNDDEV_ERROR_UnprepareHeader=5,
    SNDDEV_ERROR_Reset=6,
    SNDDEV_ERROR_Restart=7,
    SNDDEV_ERROR_GetPosition=8,
    SNDDEV_ERROR_Write=9,
    SNDDEV_ERROR_Pause=10,
    SNDDEV_ERROR_Stop=11,
    SNDDEV_ERROR_Start=12,
    SNDDEV_ERROR_AddBuffer=13,
    SNDDEV_ERROR_Query=14
} SNDDEV_ERR;

#define EC_SND_DEVICE_ERROR_BASE 0x0200
#define EC_SNDDEV_IN_ERROR       (EC_SND_DEVICE_ERROR_BASE+0x00)
#define EC_SNDDEV_OUT_ERROR      (EC_SND_DEVICE_ERROR_BASE+0x01)

#endif  /* __AUDEVCOD__ */
