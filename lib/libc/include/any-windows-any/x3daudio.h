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

#ifndef _X3DAUDIO_H
#define _X3DAUDIO_H

typedef struct X3DAUDIO_VECTOR {
    float x, y, z;
} X3DAUDIO_VECTOR;

typedef struct X3DAUDIO_CONE {
    float InnerAngle;
    float OuterAngle;
    float InnerVolume;
    float OuterVolume;
    float InnerLPF;
    float OuterLPF;
    float InnerReverb;
    float OuterReverb;
} X3DAUDIO_CONE;

typedef struct X3DAUDIO_DISTANCE_CURVE_POINT {
    float Distance;
    float DSPSetting;
} X3DAUDIO_DISTANCE_CURVE_POINT;

typedef struct X3DAUDIO_DISTANCE_CURVE {
    X3DAUDIO_DISTANCE_CURVE_POINT *pPoints;
    UINT32 PointCount;
} X3DAUDIO_DISTANCE_CURVE;

typedef struct X3DAUDIO_LISTENER {
    X3DAUDIO_VECTOR OrientFront;
    X3DAUDIO_VECTOR OrientTop;
    X3DAUDIO_VECTOR Position;
    X3DAUDIO_VECTOR Velocity;
    X3DAUDIO_CONE *pCone;
} X3DAUDIO_LISTENER;

typedef struct X3DAUDIO_EMITTER {
    X3DAUDIO_CONE *pCone;
    X3DAUDIO_VECTOR OrientFront;
    X3DAUDIO_VECTOR OrientTop;
    X3DAUDIO_VECTOR Position;
    X3DAUDIO_VECTOR Velocity;
    float InnerRadius;
    float InnerRadiusAngle;
    UINT32 ChannelCount;
    float ChannelRadius;
    float *pChannelAzimuths;
    X3DAUDIO_DISTANCE_CURVE *pVolumeCurve;
    X3DAUDIO_DISTANCE_CURVE *pLFECurve;
    X3DAUDIO_DISTANCE_CURVE *pLPFDirectCurve;
    X3DAUDIO_DISTANCE_CURVE *pLPFReverbCurve;
    X3DAUDIO_DISTANCE_CURVE *pReverbCurve;
    float CurveDistanceScaler;
    float DopplerScaler;
} X3DAUDIO_EMITTER;

typedef struct X3DAUDIO_DSP_SETTINGS {
    float *pMatrixCoefficients;
    float *pDelayTimes;
    UINT32 SrcChannelCount;
    UINT32 DstChannelCount;
    float LPFDirectCoefficient;
    float LPFReverbCoefficient;
    float ReverbLevel;
    float DopplerFactor;
    float EmitterToListenerAngle;
    float EmitterToListenerDistance;
    float EmitterVelocityComponent;
    float ListenerVelocityComponent;
} X3DAUDIO_DSP_SETTINGS;

#define X3DAUDIO_CALCULATE_MATRIX           0x00000001
#define X3DAUDIO_CALCULATE_DELAY            0x00000002
#define X3DAUDIO_CALCULATE_LPF_DIRECT       0x00000004
#define X3DAUDIO_CALCULATE_LPF_REVERB       0x00000008
#define X3DAUDIO_CALCULATE_REVERB           0x00000010
#define X3DAUDIO_CALCULATE_DOPPLER          0x00000020
#define X3DAUDIO_CALCULATE_EMITTER_ANGLE    0x00000040
#define X3DAUDIO_CALCULATE_ZEROCENTER       0x00010000
#define X3DAUDIO_CALCULATE_REDIRECT_TO_LFE  0x00020000

#ifndef _SPEAKER_POSITIONS_
#define _SPEAKER_POSITIONS_
#define SPEAKER_FRONT_LEFT                  0x00000001
#define SPEAKER_FRONT_RIGHT                 0x00000002
#define SPEAKER_FRONT_CENTER                0x00000004
#define SPEAKER_LOW_FREQUENCY               0x00000008
#define SPEAKER_BACK_LEFT                   0x00000010
#define SPEAKER_BACK_RIGHT                  0x00000020
#define SPEAKER_FRONT_LEFT_OF_CENTER        0x00000040
#define SPEAKER_FRONT_RIGHT_OF_CENTER       0x00000080
#define SPEAKER_BACK_CENTER                 0x00000100
#define SPEAKER_SIDE_LEFT                   0x00000200
#define SPEAKER_SIDE_RIGHT                  0x00000400
#define SPEAKER_TOP_CENTER                  0x00000800
#define SPEAKER_TOP_FRONT_LEFT              0x00001000
#define SPEAKER_TOP_FRONT_CENTER            0x00002000
#define SPEAKER_TOP_FRONT_RIGHT             0x00004000
#define SPEAKER_TOP_BACK_LEFT               0x00008000
#define SPEAKER_TOP_BACK_CENTER             0x00010000
#define SPEAKER_TOP_BACK_RIGHT              0x00020000
#define SPEAKER_RESERVED                    0x7ffc0000
#define SPEAKER_ALL                         0x80000000
#endif

#ifndef SPEAKER_MONO
#define SPEAKER_MONO                    SPEAKER_FRONT_CENTER
#define SPEAKER_STEREO                  (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT)
#define SPEAKER_2POINT1                 (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_LOW_FREQUENCY)
#define SPEAKER_SURROUND                (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_FRONT_CENTER | SPEAKER_BACK_CENTER)
#define SPEAKER_QUAD                    (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_BACK_LEFT | SPEAKER_BACK_RIGHT)
#define SPEAKER_4POINT1                 (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_LOW_FREQUENCY | SPEAKER_BACK_LEFT | \
                                         SPEAKER_BACK_RIGHT)
#define SPEAKER_5POINT1                 (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_FRONT_CENTER | SPEAKER_LOW_FREQUENCY | \
                                         SPEAKER_BACK_LEFT | SPEAKER_BACK_RIGHT)
#define SPEAKER_7POINT1                 (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_FRONT_CENTER | SPEAKER_LOW_FREQUENCY | \
                                         SPEAKER_BACK_LEFT | SPEAKER_BACK_RIGHT | SPEAKER_FRONT_LEFT_OF_CENTER | \
                                         SPEAKER_FRONT_RIGHT_OF_CENTER)
#define SPEAKER_5POINT1_SURROUND        (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_FRONT_CENTER | SPEAKER_LOW_FREQUENCY | \
                                         SPEAKER_SIDE_LEFT  | SPEAKER_SIDE_RIGHT)
#define SPEAKER_7POINT1_SURROUND        (SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT | SPEAKER_FRONT_CENTER | SPEAKER_LOW_FREQUENCY | \
                                         SPEAKER_BACK_LEFT | SPEAKER_BACK_RIGHT | SPEAKER_SIDE_LEFT  | SPEAKER_SIDE_RIGHT)
#endif

#define X3DAUDIO_SPEED_OF_SOUND             343.5f

#define X3DAUDIO_HANDLE_BYTESIZE 20
typedef BYTE X3DAUDIO_HANDLE[X3DAUDIO_HANDLE_BYTESIZE];

HRESULT CDECL X3DAudioInitialize(UINT32, float, X3DAUDIO_HANDLE);
void CDECL X3DAudioCalculate(const X3DAUDIO_HANDLE, const X3DAUDIO_LISTENER *,
        const X3DAUDIO_EMITTER *, UINT32, X3DAUDIO_DSP_SETTINGS *);

#endif
