/*
 * Copyright 2015 Michael Müller
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

#ifndef __WINE_DXVA_H
#define __WINE_DXVA_H

#ifdef __cplusplus
extern "C" {
#endif

DEFINE_GUID(DXVA_ModeNone, 0x1b81be00, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH261_A, 0x1b81be01, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH261_B, 0x1b81be02, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);

DEFINE_GUID(DXVA_ModeH263_A, 0x1b81be03, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH263_B, 0x1b81be04, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH263_C, 0x1b81be05, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH263_D, 0x1b81be06, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH263_E, 0x1b81be07, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH263_F, 0x1b81be08, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);

DEFINE_GUID(DXVA_ModeMPEG1_A, 0x1b81be09, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeMPEG1_VLD, 0x6f3ec719, 0x3735, 0x42cc, 0x80, 0x63, 0x65, 0xcc, 0x3c, 0xb3, 0x66, 0x16);

DEFINE_GUID(DXVA_ModeMPEG2_A, 0x1b81be0a, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeMPEG2_B, 0x1b81be0b, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeMPEG2_C, 0x1b81be0c, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeMPEG2_D, 0x1b81be0d, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeMPEG2and1_VLD, 0x86695f12, 0x340e, 0x4f04, 0x9f, 0xd3, 0x92, 0x53, 0xdd, 0x32, 0x74, 0x60);

DEFINE_GUID(DXVA_ModeH264_A, 0x1b81be64, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH264_B, 0x1b81be65, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH264_C, 0x1b81be66, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH264_D, 0x1b81be67, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH264_E, 0x1b81be68, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH264_F, 0x1b81be69, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeH264_VLD_WithFMOASO_NoFGT, 0xd5f04ff9, 0x3418, 0x45d8, 0x95, 0x61, 0x32, 0xa7, 0x6a, 0xae, 0x2d, 0xdd);

DEFINE_GUID(DXVA_ModeH264_VLD_Stereo_Progressive_NoFGT, 0xd79be8da, 0x0cf1, 0x4c81, 0xb8, 0x2a, 0x69, 0xa4, 0xe2, 0x36, 0xf4, 0x3d);
DEFINE_GUID(DXVA_ModeH264_VLD_Stereo_NoFGT, 0xf9aaccbb, 0xc2b6, 0x4cfc, 0x87, 0x79, 0x57, 0x07, 0xb1, 0x76, 0x05, 0x52);
DEFINE_GUID(DXVA_ModeH264_VLD_Multiview_NoFGT, 0x705b9d82, 0x76cf, 0x49d6, 0xb7, 0xe6, 0xac, 0x88, 0x72, 0xdb, 0x01, 0x3c);

DEFINE_GUID(DXVA_ModeWMV8_A, 0x1b81be80, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeWMV8_B, 0x1b81be81, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);

DEFINE_GUID(DXVA_ModeWMV9_A, 0x1b81be90, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeWMV9_B, 0x1b81be91, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeWMV9_C, 0x1b81be94, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);

DEFINE_GUID(DXVA_ModeVC1_A, 0x1b81bea0, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeVC1_B, 0x1b81bea1, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeVC1_C, 0x1b81bea2, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeVC1_D, 0x1b81bea3, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);
DEFINE_GUID(DXVA_ModeVC1_D2010, 0x1b81bea4, 0xa0c7, 0x11d3, 0xb9, 0x84, 0x00, 0xc0, 0x4f, 0x2e, 0x73, 0xc5);

DEFINE_GUID(DXVA_ModeMPEG4pt2_VLD_Simple, 0xefd64d74, 0xc9e8, 0x41d7, 0xa5, 0xe9, 0xe9, 0xb0, 0xe3, 0x9f, 0xa3, 0x19);
DEFINE_GUID(DXVA_ModeMPEG4pt2_VLD_AdvSimple_NoGMC, 0xed418a9f, 0x010d, 0x4eda, 0x9a, 0xe3, 0x9a, 0x65, 0x35, 0x8d, 0x8d, 0x2e);
DEFINE_GUID(DXVA_ModeMPEG4pt2_VLD_AdvSimple_GMC, 0xab998b5b, 0x4258, 0x44a9, 0x9f, 0xeb, 0x94, 0xe5, 0x97, 0xa6, 0xba, 0xae);

DEFINE_GUID(DXVA_ModeHEVC_VLD_Main, 0x5b11d51b, 0x2f4c, 0x4452, 0xbc, 0xc3, 0x09, 0xf2, 0xa1, 0x16, 0x0c, 0xc0);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main10, 0x107af0e0, 0xef1a, 0x4d19, 0xab, 0xa8, 0x67, 0xa1, 0x63, 0x07, 0x3d, 0x13);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Monochrome, 0x0685b993, 0x3d8c, 0x43a0, 0x8b, 0x28, 0xd7, 0x4c, 0x2d, 0x68, 0x99, 0xa4);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Monochrome10, 0x142a1d0f, 0x69dd, 0x4ec9, 0x85, 0x91, 0xb1, 0x2f, 0xfc, 0xb9, 0x1a, 0x29);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main12, 0x1a72925f, 0x0c2c, 0x4f15, 0x96, 0xfb, 0xb1, 0x7d, 0x14, 0x73, 0x60, 0x3f);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main10_422, 0x0bac4fe5, 0x1532, 0x4429, 0xa8, 0x54, 0xf8, 0x4d, 0xe0, 0x49, 0x53, 0xdb);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main12_422, 0x55bcac81, 0xf311, 0x4093, 0xa7, 0xd0, 0x1c, 0xbc, 0x0b, 0x84, 0x9b, 0xee);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main_444, 0x4008018f, 0xf537, 0x4b36, 0x98, 0xcf, 0x61, 0xaf, 0x8a, 0x2c, 0x1a, 0x33);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main10_Ext, 0x9cc55490, 0xe37c, 0x4932, 0x86, 0x84, 0x49, 0x20, 0xf9, 0xf6, 0x40, 0x9c);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main10_444, 0x0dabeffa, 0x4458, 0x4602, 0xbc, 0x03, 0x07, 0x95, 0x65, 0x9d, 0x61, 0x7c);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main12_444, 0x9798634d, 0xfe9d, 0x48e5, 0xb4, 0xda, 0xdb, 0xec, 0x45, 0xb3, 0xdf, 0x01);
DEFINE_GUID(DXVA_ModeHEVC_VLD_Main16, 0xa4fbdbb0, 0xa113, 0x482b, 0xa2, 0x32, 0x63, 0x5c, 0xc0, 0x69, 0x7f, 0x6d);

DEFINE_GUID(DXVA_ModeVP9_VLD_Profile0, 0x463707f8, 0xa1d0, 0x4585, 0x87, 0x6d, 0x83, 0xaa, 0x6d, 0x60, 0xb8, 0x9e);
DEFINE_GUID(DXVA_ModeVP9_VLD_10bit_Profile2, 0xa4c749ef, 0x6ecf, 0x48aa, 0x84, 0x48, 0x50, 0xa7, 0xa1, 0x16, 0x5f, 0xf7);
DEFINE_GUID(DXVA_ModeVP8_VLD, 0x90b899ea, 0x3a62, 0x4705, 0x88, 0xb3, 0x8d, 0xf0, 0x4b, 0x27, 0x44, 0xe7);

DEFINE_GUID(DXVA_ModeMJPEG_VLD_420, 0x725cb506, 0x0c29, 0x43c4, 0x94, 0x40, 0x8e, 0x93, 0x97, 0x90, 0x3a, 0x04);
DEFINE_GUID(DXVA_ModeMJPEG_VLD_422, 0x5b77b9cd, 0x1a35, 0x4c30, 0x9f, 0xd8, 0xef, 0x4b, 0x60, 0xc0, 0x35, 0xdd);
DEFINE_GUID(DXVA_ModeMJPEG_VLD_444, 0xd95161f9, 0x0d44, 0x47e6, 0xbc, 0xf5, 0x1b, 0xfb, 0xfb, 0x26, 0x8f, 0x97);
DEFINE_GUID(DXVA_ModeMJPEG_VLD_4444, 0xc91748d5, 0xfd18, 0x4aca, 0x9d, 0xb3, 0x3a, 0x66, 0x34, 0xab, 0x54, 0x7d);
DEFINE_GUID(DXVA_ModeJPEG_VLD_420, 0xcf782c83, 0xbef5, 0x4a2c, 0x87, 0xcb, 0x60, 0x19, 0xe7, 0xb1, 0x75, 0xac);
DEFINE_GUID(DXVA_ModeJPEG_VLD_422, 0xf04df417, 0xeee2, 0x4067, 0xa7, 0x78, 0xf3, 0x5c, 0x15, 0xab, 0x97, 0x21);
DEFINE_GUID(DXVA_ModeJPEG_VLD_444, 0x4cd00e17, 0x89ba, 0x48ef, 0xb9, 0xf9, 0xed, 0xcb, 0x82, 0x71, 0x3f, 0x65);

DEFINE_GUID(DXVA_NoEncrypt, 0x1b81bed0, 0xa0c7,0x11d3, 0xb9,0x84,0x00,0xc0,0x4f,0x2e,0x73,0xc5);

#define DXVA_ModeH264_MoComp_NoFGT  DXVA_ModeH264_A
#define DXVA_ModeH264_MoComp_FGT    DXVA_ModeH264_B
#define DXVA_ModeH264_IDCT_NoFGT    DXVA_ModeH264_C
#define DXVA_ModeH264_IDCT_FGT      DXVA_ModeH264_D
#define DXVA_ModeH264_VLD_NoFGT     DXVA_ModeH264_E
#define DXVA_ModeH264_VLD_FGT       DXVA_ModeH264_F

#define DXVA_USUAL_BLOCK_WIDTH   8
#define DXVA_USUAL_BLOCK_HEIGHT  8
#define DXVA_USUAL_BLOCK_SIZE   (DXVA_USUAL_BLOCK_WIDTH * DXVA_USUAL_BLOCK_HEIGHT)

#define DXVA_PICTURE_DECODING_FUNCTION          1
#define DXVA_ALPHA_BLEND_DATA_LOAD_FUNCTION     2
#define DXVA_ALPHA_BLEND_COMBINATION_FUNCTION   3
#define DXVA_PICTURE_RESAMPLE_FUNCTION          4
#define DXVA_DEBLOCKING_FILTER_FUNCTION         5
#define DXVA_FILM_GRAIN_SYNTHESIS_FUNCTION      6
#define DXVA_STATUS_REPORTING_FUNCTION          7

#pragma pack(push,1)

typedef struct _DXVA_PicEntry_H264
{
    union
    {
        struct
        {
            UCHAR Index7Bits     : 7;
            UCHAR AssociatedFlag : 1;
        } DUMMYSTRUCTNAME;
        UCHAR bPicEntry;
    } DUMMYUNIONNAME;
} DXVA_PicEntry_H264, *LPDXVA_PicEntry_H264;

typedef struct _DXVA_FilmGrainCharacteristics
{
    USHORT  wFrameWidthInMbsMinus1;
    USHORT  wFrameHeightInMbsMinus1;
    DXVA_PicEntry_H264 InPic;
    DXVA_PicEntry_H264 OutPic;
    USHORT  PicOrderCnt_offset;
    INT     CurrPicOrderCnt;
    UINT    StatusReportFeedbackNumber;
    UCHAR   model_id;
    UCHAR   separate_colour_description_present_flag;
    UCHAR   film_grain_bit_depth_luma_minus8;
    UCHAR   film_grain_bit_depth_chroma_minus8;
    UCHAR   film_grain_full_range_flag;
    UCHAR   film_grain_colour_primaries;
    UCHAR   film_grain_transfer_characteristics;
    UCHAR   film_grain_matrix_coefficients;
    UCHAR   blending_mode_id;
    UCHAR   log2_scale_factor;
    UCHAR   comp_model_present_flag[4];
    UCHAR   num_intensity_intervals_minus1[4];
    UCHAR   num_model_values_minus1[4];
    UCHAR   intensity_interval_lower_bound[3][16];
    UCHAR   intensity_interval_upper_bound[3][16];
    SHORT   comp_model_value[3][16][8];
} DXVA_FilmGrainChar_H264, *LPDXVA_FilmGrainChar_H264;

typedef struct _DXVA_PictureParameters
{
    WORD wDecodedPictureIndex;
    WORD wDeblockedPictureIndex;
    WORD wForwardRefPictureIndex;
    WORD wBackwardRefPictureIndex;
    WORD wPicWidthInMBminus1;
    WORD wPicHeightInMBminus1;
    BYTE bMacroblockWidthMinus1;
    BYTE bMacroblockHeightMinus1;
    BYTE bBlockWidthMinus1;
    BYTE bBlockHeightMinus1;
    BYTE bBPPminus1;
    BYTE bPicStructure;
    BYTE bSecondField;
    BYTE bPicIntra;
    BYTE bPicBackwardPrediction;
    BYTE bBidirectionalAveragingMode;
    BYTE bMVprecisionAndChromaRelation;
    BYTE bChromaFormat;
    BYTE bPicScanFixed;
    BYTE bPicScanMethod;
    BYTE bPicReadbackRequests;
    BYTE bRcontrol;
    BYTE bPicSpatialResid8;
    BYTE bPicOverflowBlocks;
    BYTE bPicExtrapolation;
    BYTE bPicDeblocked;
    BYTE bPicDeblockConfined;
    BYTE bPic4MVallowed;
    BYTE bPicOBMC;
    BYTE bPicBinPB;
    BYTE bMV_RPS;
    BYTE bReservedBits;
    WORD wBitstreamFcodes;
    WORD wBitstreamPCEelements;
    BYTE bBitstreamConcealmentNeed;
    BYTE bBitstreamConcealmentMethod;
} DXVA_PictureParameters, *LPDXVA_PictureParameters;

typedef struct _DXVA_SliceInfo
{
    WORD wHorizontalPosition;
    WORD wVerticalPosition;
    DWORD dwSliceBitsInBuffer;
    DWORD dwSliceDataLocation;
    BYTE bStartCodeBitOffset;
    BYTE bReservedBits;
    WORD wMBbitOffset;
    WORD wNumberMBsInSlice;
    WORD wQuantizerScaleCode;
    WORD wBadSliceChopping;
} DXVA_SliceInfo, *LPDXVA_SliceInfo;

typedef struct _DXVA_QmatrixData
{
    BYTE bNewQmatrix[4];
    WORD Qmatrix[4][DXVA_USUAL_BLOCK_WIDTH * DXVA_USUAL_BLOCK_HEIGHT];
} DXVA_QmatrixData, *LPDXVA_QmatrixData;

typedef struct _DXVA_PicParams_H264
{
    USHORT wFrameWidthInMbsMinus1;
    USHORT wFrameHeightInMbsMinus1;
    DXVA_PicEntry_H264 CurrPic;
    UCHAR num_ref_frames;
    union
    {
        struct
        {
            USHORT field_pic_flag                   : 1;
            USHORT MbaffFrameFlag                   : 1;
            USHORT residual_colour_transform_flag   : 1;
            USHORT sp_for_switch_flag               : 1;
            USHORT chroma_format_idc                : 2;
            USHORT RefPicFlag                       : 1;
            USHORT constrained_intra_pred_flag      : 1;
            USHORT weighted_pred_flag               : 1;
            USHORT weighted_bipred_idc              : 2;
            USHORT MbsConsecutiveFlag               : 1;
            USHORT frame_mbs_only_flag              : 1;
            USHORT transform_8x8_mode_flag          : 1;
            USHORT MinLumaBipredSize8x8Flag         : 1;
            USHORT IntraPicFlag                     : 1;
        } DUMMYSTRUCTNAME;
        USHORT wBitFields;
    } DUMMYUNIONNAME;
    UCHAR bit_depth_luma_minus8;
    UCHAR bit_depth_chroma_minus8;
    USHORT Reserved16Bits;
    UINT StatusReportFeedbackNumber;
    DXVA_PicEntry_H264 RefFrameList[16];
    INT CurrFieldOrderCnt[2];
    INT FieldOrderCntList[16][2];
    CHAR pic_init_qs_minus26;
    CHAR chroma_qp_index_offset;
    CHAR second_chroma_qp_index_offset;
    UCHAR ContinuationFlag;
    CHAR pic_init_qp_minus26;
    UCHAR num_ref_idx_l0_active_minus1;
    UCHAR num_ref_idx_l1_active_minus1;
    UCHAR Reserved8BitsA;
    USHORT FrameNumList[16];

    UINT UsedForReferenceFlags;
    USHORT NonExistingFrameFlags;
    USHORT frame_num;
    UCHAR log2_max_frame_num_minus4;
    UCHAR pic_order_cnt_type;
    UCHAR log2_max_pic_order_cnt_lsb_minus4;
    UCHAR delta_pic_order_always_zero_flag;
    UCHAR direct_8x8_inference_flag;
    UCHAR entropy_coding_mode_flag;
    UCHAR pic_order_present_flag;
    UCHAR num_slice_groups_minus1;
    UCHAR slice_group_map_type;
    UCHAR deblocking_filter_control_present_flag;
    UCHAR redundant_pic_cnt_present_flag;
    UCHAR Reserved8BitsB;
    USHORT slice_group_change_rate_minus1;
    UCHAR SliceGroupMap[810];
} DXVA_PicParams_H264, *LPDXVA_PicParams_H264;

typedef struct _DXVA_Qmatrix_H264
{
    UCHAR bScalingLists4x4[6][16];
    UCHAR bScalingLists8x8[2][64];
} DXVA_Qmatrix_H264, *LPDXVA_Qmatrix_H264;

typedef struct _DXVA_Slice_H264_Long
{
    UINT BSNALunitDataLocation;
    UINT SliceBytesInBuffer;
    USHORT wBadSliceChopping;
    USHORT first_mb_in_slice;
    USHORT NumMbsForSlice;
    USHORT BitOffsetToSliceData;
    UCHAR slice_type;
    UCHAR luma_log2_weight_denom;
    UCHAR chroma_log2_weight_denom;

    UCHAR num_ref_idx_l0_active_minus1;
    UCHAR num_ref_idx_l1_active_minus1;
    CHAR slice_alpha_c0_offset_div2;
    CHAR slice_beta_offset_div2;
    UCHAR Reserved8Bits;
    DXVA_PicEntry_H264 RefPicList[2][32];
    SHORT Weights[2][32][3][2];
    CHAR slice_qs_delta;
    CHAR slice_qp_delta;
    UCHAR redundant_pic_cnt;
    UCHAR direct_spatial_mv_pred_flag;
    UCHAR cabac_init_idc;
    UCHAR disable_deblocking_filter_idc;
    USHORT slice_id;
} DXVA_Slice_H264_Long, *LPDXVA_Slice_H264_Long;

typedef struct _DXVA_Slice_H264_Short
{
    UINT BSNALunitDataLocation;
    UINT SliceBytesInBuffer;
    USHORT wBadSliceChopping;
} DXVA_Slice_H264_Short, *LPDXVA_Slice_H264_Short;

typedef struct _DXVA_Status_H264
{
    UINT StatusReportFeedbackNumber;
    DXVA_PicEntry_H264 CurrPic;
    UCHAR field_pic_flag;
    UCHAR bDXVA_Func;
    UCHAR bBufType;
    UCHAR bStatus;
    UCHAR bReserved8Bits;
    USHORT wNumMbsAffected;
} DXVA_Status_H264, *LPDXVA_Status_H264;

typedef struct _DXVA_PicEntry_HEVC
{
    union
    {
        struct
        {
            UCHAR Index7Bits : 7;
            UCHAR AssociatedFlag : 1;
        };
        UCHAR bPicEntry;
    };
} DXVA_PicEntry_HEVC, *LPDXVA_PicEntry_HEVC;

typedef struct _DXVA_PicParams_HEVC
{
    USHORT      PicWidthInMinCbsY;
    USHORT      PicHeightInMinCbsY;
    union
    {
        struct
        {
            USHORT  chroma_format_idc                       : 2;
            USHORT  separate_colour_plane_flag              : 1;
            USHORT  bit_depth_luma_minus8                   : 3;
            USHORT  bit_depth_chroma_minus8                 : 3;
            USHORT  log2_max_pic_order_cnt_lsb_minus4       : 4;
            USHORT  NoPicReorderingFlag                     : 1;
            USHORT  NoBiPredFlag                            : 1;
            USHORT  ReservedBits1                            : 1;
        };
        USHORT wFormatAndSequenceInfoFlags;
    };
    DXVA_PicEntry_HEVC  CurrPic;
    UCHAR   sps_max_dec_pic_buffering_minus1;
    UCHAR   log2_min_luma_coding_block_size_minus3;
    UCHAR   log2_diff_max_min_luma_coding_block_size;
    UCHAR   log2_min_transform_block_size_minus2;
    UCHAR   log2_diff_max_min_transform_block_size;
    UCHAR   max_transform_hierarchy_depth_inter;
    UCHAR   max_transform_hierarchy_depth_intra;
    UCHAR   num_short_term_ref_pic_sets;
    UCHAR   num_long_term_ref_pics_sps;
    UCHAR   num_ref_idx_l0_default_active_minus1;
    UCHAR   num_ref_idx_l1_default_active_minus1;
    CHAR    init_qp_minus26;
    UCHAR   ucNumDeltaPocsOfRefRpsIdx;
    USHORT  wNumBitsForShortTermRPSInSlice;
    USHORT  ReservedBits2;

    union
    {
        struct
        {
            UINT32  scaling_list_enabled_flag                    : 1;
            UINT32  amp_enabled_flag                            : 1;
            UINT32  sample_adaptive_offset_enabled_flag         : 1;
            UINT32  pcm_enabled_flag                            : 1;
            UINT32  pcm_sample_bit_depth_luma_minus1            : 4;
            UINT32  pcm_sample_bit_depth_chroma_minus1          : 4;
            UINT32  log2_min_pcm_luma_coding_block_size_minus3  : 2;
            UINT32  log2_diff_max_min_pcm_luma_coding_block_size : 2;
            UINT32  pcm_loop_filter_disabled_flag                : 1;
            UINT32  long_term_ref_pics_present_flag             : 1;
            UINT32  sps_temporal_mvp_enabled_flag               : 1;
            UINT32  strong_intra_smoothing_enabled_flag         : 1;
            UINT32  dependent_slice_segments_enabled_flag       : 1;
            UINT32  output_flag_present_flag                    : 1;
            UINT32  num_extra_slice_header_bits                 : 3;
            UINT32  sign_data_hiding_enabled_flag               : 1;
            UINT32  cabac_init_present_flag                     : 1;
            UINT32  ReservedBits3                               : 5;
        };
        UINT32 dwCodingParamToolFlags;
    };

    union
    {
        struct
        {
            UINT32  constrained_intra_pred_flag                 : 1;
            UINT32  transform_skip_enabled_flag                 : 1;
            UINT32  cu_qp_delta_enabled_flag                    : 1;
            UINT32  pps_slice_chroma_qp_offsets_present_flag    : 1;
            UINT32  weighted_pred_flag                          : 1;
            UINT32  weighted_bipred_flag                        : 1;
            UINT32  transquant_bypass_enabled_flag              : 1;
            UINT32  tiles_enabled_flag                          : 1;
            UINT32  entropy_coding_sync_enabled_flag            : 1;
            UINT32  uniform_spacing_flag                        : 1;
            UINT32  loop_filter_across_tiles_enabled_flag       : 1;
            UINT32  pps_loop_filter_across_slices_enabled_flag  : 1;
            UINT32  deblocking_filter_override_enabled_flag     : 1;
            UINT32  pps_deblocking_filter_disabled_flag         : 1;
            UINT32  lists_modification_present_flag             : 1;
            UINT32  slice_segment_header_extension_present_flag : 1;
            UINT32  IrapPicFlag                                 : 1;
            UINT32  IdrPicFlag                                  : 1;
            UINT32  IntraPicFlag                                : 1;
            UINT32  ReservedBits4                               : 13;
        };
        UINT32 dwCodingSettingPicturePropertyFlags;
    };
    CHAR    pps_cb_qp_offset;
    CHAR    pps_cr_qp_offset;
    UCHAR   num_tile_columns_minus1;
    UCHAR   num_tile_rows_minus1;
    USHORT  column_width_minus1[19];
    USHORT  row_height_minus1[21];
    UCHAR   diff_cu_qp_delta_depth;
    CHAR    pps_beta_offset_div2;
    CHAR    pps_tc_offset_div2;
    UCHAR   log2_parallel_merge_level_minus2;
    INT     CurrPicOrderCntVal;
    DXVA_PicEntry_HEVC	RefPicList[15];
    UCHAR   ReservedBits5;
    INT     PicOrderCntValList[15];
    UCHAR   RefPicSetStCurrBefore[8];
    UCHAR   RefPicSetStCurrAfter[8];
    UCHAR   RefPicSetLtCurr[8];
    USHORT  ReservedBits6;
    USHORT  ReservedBits7;
    UINT    StatusReportFeedbackNumber;
} DXVA_PicParams_HEVC, *LPDXVA_PicParams_HEVC;

typedef struct _DXVA_PicParams_HEVC_RangeExt
{
    DXVA_PicParams_HEVC params;
    union
    {
        struct
        {
            USHORT transform_skip_rotation_enabled_flag    : 1;
            USHORT transform_skip_context_enabled_flag     : 1;
            USHORT implicit_rdpcm_enabled_flag             : 1;
            USHORT explicit_rdpcm_enabled_flag             : 1;
            USHORT extended_precision_processing_flag      : 1;
            USHORT intra_smoothing_disabled_flag           : 1;
            USHORT persistent_rice_adaptation_enabled_flag : 1;
            USHORT high_precision_offsets_enabled_flag     : 1;
            USHORT cabac_bypass_alignment_enabled_flag     : 1;
            USHORT cross_component_prediction_enabled_flag : 1;
            USHORT chroma_qp_offset_list_enabled_flag      : 1;
            USHORT ReservedBits8                           : 5;
        };
        USHORT dwRangeExtensionFlags;
    };
    UCHAR diff_cu_chroma_qp_offset_depth;
    UCHAR log2_sao_offset_scale_luma;
    UCHAR log2_sao_offset_scale_chroma;
    UCHAR log2_max_transform_skip_block_size_minus2;
    CHAR cb_qp_offset_list[6];
    CHAR cr_qp_offset_list[6];
    UCHAR chroma_qp_offset_list_len_minus1;
    USHORT ReservedBits9;
} DXVA_PicParams_HEVC_RangeExt, *LPDXVA_PicParams_HEVC_RangeExt;

typedef struct _DXVA_Qmatrix_HEVC
{
    UCHAR ucScalingLists0[6][16];
    UCHAR ucScalingLists1[6][64];
    UCHAR ucScalingLists2[6][64];
    UCHAR ucScalingLists3[2][64];
    UCHAR ucScalingListDCCoefSizeID2[6];
    UCHAR ucScalingListDCCoefSizeID3[2];
} DXVA_Qmatrix_HEVC, *LPDXVA_Qmatrix_HEVC;

typedef struct _DXVA_Slice_HEVC_Short
{
    UINT    BSNALunitDataLocation;
    UINT    SliceBytesInBuffer;
    USHORT  wBadSliceChopping;
} DXVA_Slice_HEVC_Short, *LPDXVA_Slice_HEVC_Short;

typedef struct _DXVA_PicEntry_VPx
{
    union
    {
        struct
        {
            UCHAR Index7Bits     : 7;
            UCHAR AssociatedFlag : 1;
        };
        UCHAR bPicEntry;
    };
} DXVA_PicEntry_VPx, *LPDXVA_PicEntry_VPx;

typedef struct _segmentation_VP9
{
    union
    {
        struct
        {
            UCHAR enabled                   : 1;
            UCHAR update_map                : 1;
            UCHAR temporal_update           : 1;
            UCHAR abs_delta                 : 1;
            UCHAR ReservedSegmentFlags4Bits : 4;
        };
        UCHAR wSegmentInfoFlags;
    };
    UCHAR tree_probs[7];
    UCHAR pred_probs[3];
    SHORT feature_data[8][4];
    UCHAR feature_mask[8];
} DXVA_segmentation_VP9;

typedef struct _DXVA_PicParams_VP9
{
    DXVA_PicEntry_VPx    CurrPic;
    UCHAR                profile;
    union
    {
        struct
        {
            USHORT frame_type                   : 1;
            USHORT show_frame                   : 1;
            USHORT error_resilient_mode         : 1;
            USHORT subsampling_x                : 1;
            USHORT subsampling_y                : 1;
            USHORT extra_plane                  : 1;
            USHORT refresh_frame_context        : 1;
            USHORT frame_parallel_decoding_mode : 1;
            USHORT intra_only                   : 1;
            USHORT frame_context_idx            : 2;
            USHORT reset_frame_context          : 2;
            USHORT allow_high_precision_mv      : 1;
            USHORT ReservedFormatInfo2Bits      : 2;
        };
        USHORT wFormatAndPictureInfoFlags;
    };
    UINT  width;
    UINT  height;
    UCHAR BitDepthMinus8Luma;
    UCHAR BitDepthMinus8Chroma;
    UCHAR interp_filter;
    UCHAR Reserved8Bits;
    DXVA_PicEntry_VPx  ref_frame_map[8];
    UINT  ref_frame_coded_width[8];
    UINT  ref_frame_coded_height[8];
    DXVA_PicEntry_VPx  frame_refs[3];
    CHAR  ref_frame_sign_bias[4];
    CHAR  filter_level;
    CHAR  sharpness_level;
    union
    {
        struct
        {
            UCHAR mode_ref_delta_enabled   : 1;
            UCHAR mode_ref_delta_update    : 1;
            UCHAR use_prev_in_find_mv_refs : 1;
            UCHAR ReservedControlInfo5Bits : 5;
        };
        UCHAR wControlInfoFlags;
    };
    CHAR   ref_deltas[4];
    CHAR   mode_deltas[2];
    SHORT  base_qindex;
    CHAR   y_dc_delta_q;
    CHAR   uv_dc_delta_q;
    CHAR   uv_ac_delta_q;
    DXVA_segmentation_VP9 stVP9Segments;
    UCHAR  log2_tile_cols;
    UCHAR  log2_tile_rows;
    USHORT uncompressed_header_size_byte_aligned;
    USHORT first_partition_size;
    USHORT Reserved16Bits;
    UINT   Reserved32Bits;
    UINT   StatusReportFeedbackNumber;
} DXVA_PicParams_VP9, *LPDXVA_PicParams_VP9;

typedef struct _segmentation_VP8
{
    union
    {
        struct
        {
            UCHAR segmentation_enabled        : 1;
            UCHAR update_mb_segmentation_map  : 1;
            UCHAR update_mb_segmentation_data : 1;
            UCHAR mb_segement_abs_delta       : 1;
            UCHAR ReservedSegmentFlags4Bits   : 4;
        };
        UCHAR wSegmentFlags;
    };
    CHAR  segment_feature_data[2][4];
    UCHAR mb_segment_tree_probs[3];
} DXVA_segmentation_VP8;

typedef struct _DXVA_PicParams_VP8
{
    UINT first_part_size;
    UINT width;
    UINT height;
    DXVA_PicEntry_VPx  CurrPic;
    union
    {
        struct
        {
            UCHAR frame_type            : 1;
            UCHAR version               : 3;
            UCHAR show_frame            : 1;
            UCHAR clamp_type            : 1;
            UCHAR ReservedFrameTag3Bits : 2;
        };
        UCHAR wFrameTagFlags;
    };
    DXVA_segmentation_VP8  stVP8Segments;
    UCHAR  filter_type;
    UCHAR  filter_level;
    UCHAR  sharpness_level;
    UCHAR  mode_ref_lf_delta_enabled;
    UCHAR  mode_ref_lf_delta_update;
    CHAR   ref_lf_deltas[4];
    CHAR   mode_lf_deltas[4];
    UCHAR  log2_nbr_of_dct_partitions;
    UCHAR  base_qindex;
    CHAR   y1dc_delta_q;
    CHAR   y2dc_delta_q;
    CHAR   y2ac_delta_q;
    CHAR   uvdc_delta_q;
    CHAR   uvac_delta_q;
    DXVA_PicEntry_VPx alt_fb_idx;
    DXVA_PicEntry_VPx gld_fb_idx;
    DXVA_PicEntry_VPx lst_fb_idx;
    UCHAR  ref_frame_sign_bias_golden;
    UCHAR  ref_frame_sign_bias_altref;
    UCHAR  refresh_entropy_probs;
    UCHAR  vp8_coef_update_probs[4][8][3][11];
    UCHAR  mb_no_coeff_skip;
    UCHAR  prob_skip_false;
    UCHAR  prob_intra;
    UCHAR  prob_last;
    UCHAR  prob_golden;
    UCHAR  intra_16x16_prob[4];
    UCHAR  intra_chroma_prob[3];
    UCHAR  vp8_mv_update_probs[2][19];
    USHORT ReservedBits1;
    USHORT ReservedBits2;
    USHORT ReservedBits3;
    UINT   StatusReportFeedbackNumber;
} DXVA_PicParams_VP8, *LPDXVA_PicParams_VP8;

typedef struct _DXVA_Slice_VPx_Short
{
    UINT   BSNALunitDataLocation;
    UINT   SliceBytesInBuffer;
    USHORT wBadSliceChopping;
} DXVA_Slice_VPx_Short, *LPDXVA_Slice_VPx_Short;

typedef struct _DXVA_Status_VPx
{
    UINT   StatusReportFeedbackNumber;
    DXVA_PicEntry_VPx CurrPic;
    UCHAR  bBufType;
    UCHAR  bStatus;
    UCHAR  bReserved8Bits;
    USHORT wNumMbsAffected;
} DXVA_Status_VPx, *LPDXVA_Status_VPx;


#define _DIRECTX_AV1_VA_

/* AV1 decoder GUIDs */
DEFINE_GUID(DXVA_ModeAV1_VLD_Profile0,           0xb8be4ccb, 0xcf53, 0x46ba, 0x8d, 0x59, 0xd6, 0xb8, 0xa6, 0xda, 0x5d, 0x2a);
DEFINE_GUID(DXVA_ModeAV1_VLD_Profile1,           0x6936ff0f, 0x45b1, 0x4163, 0x9c, 0xc1, 0x64, 0x6e, 0xf6, 0x94, 0x61, 0x08);
DEFINE_GUID(DXVA_ModeAV1_VLD_Profile2,           0x0c5f2aa1, 0xe541, 0x4089, 0xbb, 0x7b, 0x98, 0x11, 0x0a, 0x19, 0xd7, 0xc8);
DEFINE_GUID(DXVA_ModeAV1_VLD_12bit_Profile2,     0x17127009, 0xa00f, 0x4ce1, 0x99, 0x4e, 0xbf, 0x40, 0x81, 0xf6, 0xf3, 0xf0);
DEFINE_GUID(DXVA_ModeAV1_VLD_12bit_Profile2_420, 0x2d80bed6, 0x9cac, 0x4835, 0x9e, 0x91, 0x32, 0x7b, 0xbc, 0x4f, 0x9e, 0xe8);

/* AV1 picture entry data structure */
typedef struct _DXVA_PicEntry_AV1 {
    UINT width;
    UINT height;

    INT wmmat[6];
    __C89_NAMELESS union {
        __C89_NAMELESS struct {
            UCHAR wminvalid : 1;
            UCHAR wmtype : 2;
            UCHAR Reserved : 5;
        } __C89_NAMELESSSTRUCTNAME;
        UCHAR GlobalMotionFlags;
    } __C89_NAMELESSUNIONNAME;
    UCHAR Index;
    UINT16 Reserved16Bits;
} DXVA_PicEntry_AV1, *LPDXVA_PicEntry_AV1;

/* AV1 picture parameters data structure */
typedef struct _DXVA_PicParams_AV1 {
    UINT width;
    UINT height;

    UINT max_width;
    UINT max_height;

    UCHAR CurrPicTextureIndex;
    UCHAR superres_denom;
    UCHAR bitdepth;
    UCHAR seq_profile;

    struct {
        UCHAR cols;
        UCHAR rows;
        USHORT context_update_id;
        USHORT widths[64];
        USHORT heights[64];
    } tiles;

    union {
        __C89_NAMELESS struct {
            UINT use_128x128_superblock : 1;
            UINT intra_edge_filter : 1;
            UINT interintra_compound : 1;
            UINT masked_compound : 1;
            UINT warped_motion : 1;
            UINT dual_filter : 1;
            UINT jnt_comp : 1;
            UINT screen_content_tools : 1;
            UINT integer_mv : 1;
            UINT cdef : 1;
            UINT restoration : 1;
            UINT film_grain : 1;
            UINT intrabc : 1;
            UINT high_precision_mv : 1;
            UINT switchable_motion_mode : 1;
            UINT filter_intra : 1;
            UINT disable_frame_end_update_cdf : 1;
            UINT disable_cdf_update : 1;
            UINT reference_mode : 1;
            UINT skip_mode : 1;
            UINT reduced_tx_set : 1;
            UINT superres : 1;
            UINT tx_mode : 2;
            UINT use_ref_frame_mvs : 1;
            UINT enable_ref_frame_mvs : 1;
            UINT reference_frame_update : 1;
            UINT Reserved : 5;
        } __C89_NAMELESSSTRUCTNAME;
        UINT32 CodingParamToolFlags;
    } coding;

    union {
        __C89_NAMELESS struct {
            UCHAR frame_type : 2;
            UCHAR show_frame : 1;
            UCHAR showable_frame : 1;
            UCHAR subsampling_x : 1;
            UCHAR subsampling_y : 1;
            UCHAR mono_chrome : 1;
            UCHAR Reserved : 1;
        } __C89_NAMELESSSTRUCTNAME;
        UCHAR FormatAndPictureInfoFlags;
    } format;

    UCHAR primary_ref_frame;
    UCHAR order_hint;
    UCHAR order_hint_bits;

    DXVA_PicEntry_AV1 frame_refs[7];
    UCHAR RefFrameMapTextureIndex[8];

    struct {
        UCHAR filter_level[2];
        UCHAR filter_level_u;
        UCHAR filter_level_v;

        UCHAR sharpness_level;
        __C89_NAMELESS union {
            __C89_NAMELESS struct {
                UCHAR mode_ref_delta_enabled : 1;
                UCHAR mode_ref_delta_update : 1;
                UCHAR delta_lf_multi : 1;
                UCHAR delta_lf_present : 1;
                UCHAR Reserved : 4;
            } __C89_NAMELESSSTRUCTNAME;
            UCHAR ControlFlags;
        } __C89_NAMELESSUNIONNAME;
        CHAR ref_deltas[8];
        CHAR mode_deltas[2];
        UCHAR delta_lf_res;
        UCHAR frame_restoration_type[3];
        USHORT log2_restoration_unit_size[3];
        UINT16 Reserved16Bits;
    } loop_filter;

    struct {
        __C89_NAMELESS union {
            __C89_NAMELESS struct {
                UCHAR delta_q_present : 1;
                UCHAR delta_q_res : 2;
                UCHAR Reserved : 5;
            } __C89_NAMELESSSTRUCTNAME;
            UCHAR ControlFlags;
        } __C89_NAMELESSUNIONNAME;

        UCHAR base_qindex;
        CHAR y_dc_delta_q;
        CHAR u_dc_delta_q;
        CHAR v_dc_delta_q;
        CHAR u_ac_delta_q;
        CHAR v_ac_delta_q;
        UCHAR qm_y;
        UCHAR qm_u;
        UCHAR qm_v;
        UINT16 Reserved16Bits;
    } quantization;

    struct {
        __C89_NAMELESS union {
            __C89_NAMELESS struct {
                UCHAR damping : 2;
                UCHAR bits : 2;
                UCHAR Reserved : 4;
            } __C89_NAMELESSSTRUCTNAME;
            UCHAR ControlFlags;
        } __C89_NAMELESSUNIONNAME;

        union {
            __C89_NAMELESS struct {
                UCHAR primary : 6;
                UCHAR secondary : 2;
            } __C89_NAMELESSSTRUCTNAME;
            UCHAR combined;
        } y_strengths[8];

        union {
            __C89_NAMELESS struct {
                UCHAR primary : 6;
                UCHAR secondary : 2;
            } __C89_NAMELESSSTRUCTNAME;
            UCHAR combined;
        } uv_strengths[8];

    } cdef;

    UCHAR interp_filter;

    struct {
        __C89_NAMELESS union {
            __C89_NAMELESS struct {
                UCHAR enabled : 1;
                UCHAR update_map : 1;
                UCHAR update_data : 1;
                UCHAR temporal_update : 1;
                UCHAR Reserved : 4;
            } __C89_NAMELESSSTRUCTNAME;
            UCHAR ControlFlags;
        } __C89_NAMELESSUNIONNAME;
        UCHAR Reserved24Bits[3];

        union {
            __C89_NAMELESS struct {
                UCHAR alt_q : 1;
                UCHAR alt_lf_y_v : 1;
                UCHAR alt_lf_y_h : 1;
                UCHAR alt_lf_u : 1;
                UCHAR alt_lf_v : 1;
                UCHAR ref_frame : 1;
                UCHAR skip : 1;
                UCHAR globalmv : 1;
            } __C89_NAMELESSSTRUCTNAME;
            UCHAR mask;
        } feature_mask[8];

        SHORT feature_data[8][8];

    } segmentation;

    struct {
        __C89_NAMELESS union {
            __C89_NAMELESS struct {
                USHORT apply_grain : 1;
                USHORT scaling_shift_minus8 : 2;
                USHORT chroma_scaling_from_luma : 1;
                USHORT ar_coeff_lag : 2;
                USHORT ar_coeff_shift_minus6 : 2;
                USHORT grain_scale_shift : 2;
                USHORT overlap_flag : 1;
                USHORT clip_to_restricted_range : 1;
                USHORT matrix_coeff_is_identity : 1;
                USHORT Reserved : 3;
            } __C89_NAMELESSSTRUCTNAME;
            USHORT ControlFlags;
        } __C89_NAMELESSUNIONNAME;

        USHORT grain_seed;
        UCHAR scaling_points_y[14][2];
        UCHAR num_y_points;
        UCHAR scaling_points_cb[10][2];
        UCHAR num_cb_points;
        UCHAR scaling_points_cr[10][2];
        UCHAR num_cr_points;
        UCHAR ar_coeffs_y[24];
        UCHAR ar_coeffs_cb[25];
        UCHAR ar_coeffs_cr[25];
        UCHAR cb_mult;
        UCHAR cb_luma_mult;
        UCHAR cr_mult;
        UCHAR cr_luma_mult;
        UCHAR Reserved8Bits;
        SHORT cb_offset;
        SHORT cr_offset;
    } film_grain;

    UINT   Reserved32Bits;
    UINT   StatusReportFeedbackNumber;
} DXVA_PicParams_AV1, *LPDXVA_PicParams_AV1;

/* AV1 tile data structure */
typedef struct _DXVA_Tile_AV1 {
    UINT   DataOffset;
    UINT   DataSize;
    USHORT row;
    USHORT column;
    UINT16 Reserved16Bits;
    UCHAR  anchor_frame;
    UCHAR  Reserved8Bits;
} DXVA_Tile_AV1, *LPDXVA_Tile_AV1;

typedef struct _DXVA_Status_AV1 {
    UINT  StatusReportFeedbackNumber;
    DXVA_PicEntry_AV1 CurrPic;
    UCHAR  BufType;
    UCHAR  Status;
    UCHAR  Reserved8Bits;
    USHORT NumMbsAffected;
} DXVA_Status_AV1, *LPDXVA_Status_AV1;

#pragma pack(pop)

typedef enum _DXVA_VideoChromaSubsampling
{
    DXVA_VideoChromaSubsampling_Vertically_AlignedChromaPlanes  = 0x1,
    DXVA_VideoChromaSubsampling_Vertically_Cosited              = 0x2,
    DXVA_VideoChromaSubsampling_Horizontally_Cosited            = 0x4,
    DXVA_VideoChromaSubsampling_ProgressiveChroma               = 0x8,

    DXVA_VideoChromaSubsampling_Unknown = 0,
    DXVA_VideoChromaSubsampling_Cosited = DXVA_VideoChromaSubsampling_Vertically_AlignedChromaPlanes
            | DXVA_VideoChromaSubsampling_Vertically_Cosited
            | DXVA_VideoChromaSubsampling_Horizontally_Cosited,
    DXVA_VideoChromaSubsampling_DV_PAL = DXVA_VideoChromaSubsampling_Vertically_Cosited
            | DXVA_VideoChromaSubsampling_Horizontally_Cosited,
    DXVA_VideoChromaSubsampling_MPEG1 = DXVA_VideoChromaSubsampling_Vertically_AlignedChromaPlanes,
    DXVA_VideoChromaSubsampling_MPEG2 = DXVA_VideoChromaSubsampling_Vertically_AlignedChromaPlanes
            | DXVA_VideoChromaSubsampling_Horizontally_Cosited,
} DXVA_VideoChromaSubsampling;

typedef enum _DXVA_NominalRange
{
    DXVA_NominalRange_Unknown = 0,
    DXVA_NominalRange_0_255 = 1,
    DXVA_NominalRange_16_235 = 2,
    DXVA_NominalRange_48_208 = 3,
    DXVA_NominalRange_Normal = DXVA_NominalRange_0_255,
    DXVA_NominalRange_Wide = DXVA_NominalRange_16_235,
} DXVA_NominalRange;

typedef enum _DXVA_VideoTransferMatrix
{
    DXVA_VideoTransferMatrix_Unknown = 0,
    DXVA_VideoTransferMatrix_BT709 = 1,
    DXVA_VideoTransferMatrix_BT601 = 2,
    DXVA_VideoTransferMatrix_SMPTE240M = 3,
} DXVA_VideoTransferMatrix;

typedef enum _DXVA_VideoLighting
{
    DXVA_VideoLighting_Unknown = 0,
    DXVA_VideoLighting_bright = 1,
    DXVA_VideoLighting_office = 2,
    DXVA_VideoLighting_dim = 3,
    DXVA_VideoLighting_dark = 4,
} DXVA_VideoLighting;

typedef enum _DXVA_VideoPrimaries
{
    DXVA_VideoPrimaries_Unknown = 0,
    DXVA_VideoPrimaries_reserved = 1,
    DXVA_VideoPrimaries_BT709 = 2,
    DXVA_VideoPrimaries_BT470_2_SysM = 3,
    DXVA_VideoPrimaries_BT470_2_SysBG = 4,
    DXVA_VideoPrimaries_SMPTE170M = 5,
    DXVA_VideoPrimaries_SMPTE420M = 6,
    DXVA_VideoPrimaries_EBU3213 = 7,
    DXVA_VideoPrimaries_SMPTE_C = 8,
} DXVA_VideoPrimaries;

typedef enum _DXVA_VideoTransferFunction
{
    DXVA_VideoTransFunc_Unknown = 0,
    DXVA_VideoTransFunc_10 = 1,
    DXVA_VideoTransFunc_18 = 2,
    DXVA_VideoTransFunc_20 = 3,
    DXVA_VideoTransFunc_22 = 4,
    DXVA_VideoTransFunc_22_709 = 5,
    DXVA_VideoTransFunc_22_240M = 6,
    DXVA_VideoTransFunc_22_8bit_sRGB = 7,
    DXVA_VideoTransFunc_28 = 8,
} DXVA_VideoTransferFunction;

typedef struct _DXVA_ExtendedFormat
{
    UINT SampleFormat : 8;
    UINT VideoChromaSubsampling : 4;
    DXVA_NominalRange NominalRange : 3;
    DXVA_VideoTransferMatrix VideoTransferMatrix : 3;
    DXVA_VideoLighting VideoLighting : 4;
    DXVA_VideoPrimaries VideoPrimaries : 5;
    DXVA_VideoTransferFunction VideoTransferFunction : 5;
} DXVA_ExtendedFormat;

#ifdef __cplusplus
}
#endif

#endif /* __WINE_DXVA_H */
