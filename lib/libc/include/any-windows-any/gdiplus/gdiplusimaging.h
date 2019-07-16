/*
 * gdiplusimaging.h
 *
 * GDI+ Imaging and image metadata
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Markus Koenig <markus@stber-koenig.de>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef __GDIPLUS_IMAGING_H
#define __GDIPLUS_IMAGING_H
#if __GNUC__ >=3
#pragma GCC system_header
#endif

typedef enum ImageCodecFlags {
	ImageCodecFlagsEncoder = 0x00000001,
	ImageCodecFlagsDecoder = 0x00000002,
	ImageCodecFlagsSupportBitmap = 0x00000004,
	ImageCodecFlagsSupportVector = 0x00000008,
	ImageCodecFlagsSeekableEncode = 0x00000010,
	ImageCodecFlagsBlockingDecode = 0x00000020,
	ImageCodecFlagsBuiltin = 0x00010000,
	ImageCodecFlagsSystem = 0x00020000,
	ImageCodecFlagsUser = 0x00040000
} ImageCodecFlags;

typedef enum ImageFlags {
	ImageFlagsNone = 0,
	ImageFlagsScalable = 0x00000001,
	ImageFlagsHasAlpha = 0x00000002,
	ImageFlagsHasTranslucent = 0x00000004,
	ImageFlagsPartiallyScalable = 0x00000008,
	ImageFlagsColorSpaceRGB = 0x00000010,
	ImageFlagsColorSpaceCMYK = 0x00000020,
	ImageFlagsColorSpaceGRAY = 0x00000040,
	ImageFlagsColorSpaceYCBCR = 0x00000080,
	ImageFlagsColorSpaceYCCK = 0x00000100,
	ImageFlagsHasRealDPI = 0x00001000,
	ImageFlagsHasRealPixelSize = 0x00002000,
	ImageFlagsReadOnly = 0x00010000,
	ImageFlagsCaching = 0x00020000
} ImageFlags;

typedef enum ImageLockMode {
	ImageLockModeRead = 1,
	ImageLockModeWrite = 2,
	ImageLockModeUserInputBuf = 4
} ImageLockMode;

typedef enum ItemDataPosition {
	ItemDataPositionAfterHeader = 0,
	ItemDataPositionAfterPalette = 1,
	ItemDataPositionAfterBits = 2
} ItemDataPosition;

typedef enum RotateFlipType {
	RotateNoneFlipNone = 0,
	Rotate90FlipNone = 1,
	Rotate180FlipNone = 2,
	Rotate270FlipNone = 3,
	RotateNoneFlipX = 4,
	Rotate90FlipX = 5,
	Rotate180FlipX = 6,
	Rotate270FlipX = 7,
	Rotate180FlipXY = 0,
	Rotate270FlipXY = 1, 
	RotateNoneFlipXY = 2,
	Rotate90FlipXY = 3,
	Rotate180FlipY = 4,
	Rotate270FlipY = 5,
	RotateNoneFlipY = 6,
	Rotate90FlipY = 7
} RotateFlipType;

typedef struct BitmapData {
	UINT Width;
	UINT Height;
	INT Stride;
	INT PixelFormat;  /* MSDN: "PixelFormat PixelFormat;" */
	VOID *Scan0;
	UINT_PTR Reserved;
} BitmapData;

typedef struct EncoderParameter {
	GUID Guid;
	ULONG NumberOfValues;
	ULONG Type;
	VOID *Value;
} EncoderParameter;

typedef struct EncoderParameters {
	UINT Count;
	EncoderParameter Parameter[1];
} EncoderParameters;

typedef struct ImageCodecInfo {
	CLSID Clsid;
	GUID FormatID;
	WCHAR *CodecName;
	WCHAR *DllName;
	WCHAR *FormatDescription;
	WCHAR *FilenameExtension;
	WCHAR *MimeType;
	DWORD Flags;
	DWORD Version;
	DWORD SigCount;
	DWORD SigSize;
	BYTE *SigPattern;
	BYTE *SigMask;
} ImageCodecInfo;

/* FIXME: The order of fields is probably wrong. Please don't use this
 * structure until this problem is resolved!  Can't test because
 * ImageItemData is not supported by the redistributable GDI+ 1.0 DLL. */
typedef struct ImageItemData {
	UINT Size;
	UINT Position;
	VOID *Desc;
	UINT DescSize;
	UINT *Data;
	UINT DataSize;
	UINT Cookie;
} ImageItemData;

typedef struct PropertyItem {
	PROPID id;
	ULONG length;
	WORD type;
	VOID *value;
} PropertyItem;

#define PropertyTagGpsVer ((PROPID) 0x0000)
#define PropertyTagGpsLatitudeRef ((PROPID) 0x0001)
#define PropertyTagGpsLatitude ((PROPID) 0x0002)
#define PropertyTagGpsLongitudeRef ((PROPID) 0x0003)
#define PropertyTagGpsLongitude ((PROPID) 0x0004)
#define PropertyTagGpsAltitudeRef ((PROPID) 0x0005)
#define PropertyTagGpsAltitude ((PROPID) 0x0006)
#define PropertyTagGpsGpsTime ((PROPID) 0x0007)
#define PropertyTagGpsGpsSatellites ((PROPID) 0x0008)
#define PropertyTagGpsGpsStatus ((PROPID) 0x0009)
#define PropertyTagGpsGpsMeasureMode ((PROPID) 0x000A)
#define PropertyTagGpsGpsDop ((PROPID) 0x000B)
#define PropertyTagGpsSpeedRef ((PROPID) 0x000C)
#define PropertyTagGpsSpeed ((PROPID) 0x000D)
#define PropertyTagGpsTrackRef ((PROPID) 0x000E)
#define PropertyTagGpsTrack ((PROPID) 0x000F)
#define PropertyTagGpsImgDirRef ((PROPID) 0x0010)
#define PropertyTagGpsImgDir ((PROPID) 0x0011)
#define PropertyTagGpsMapDatum ((PROPID) 0x0012)
#define PropertyTagGpsDestLatRef ((PROPID) 0x0013)
#define PropertyTagGpsDestLat ((PROPID) 0x0014)
#define PropertyTagGpsDestLongRef ((PROPID) 0x0015)
#define PropertyTagGpsDestLong ((PROPID) 0x0016)
#define PropertyTagGpsDestBearRef ((PROPID) 0x0017)
#define PropertyTagGpsDestBear ((PROPID) 0x0018)
#define PropertyTagGpsDestDistRef ((PROPID) 0x0019)
#define PropertyTagGpsDestDist ((PROPID) 0x001A)
#define PropertyTagNewSubfileType ((PROPID) 0x00FE)
#define PropertyTagSubfileType ((PROPID) 0x00FF)
#define PropertyTagImageWidth ((PROPID) 0x0100)
#define PropertyTagImageHeight ((PROPID) 0x0101)
#define PropertyTagBitsPerSample ((PROPID) 0x0102)
#define PropertyTagCompression ((PROPID) 0x0103)
#define PropertyTagPhotometricInterp ((PROPID) 0x0106)
#define PropertyTagThreshHolding ((PROPID) 0x0107)
#define PropertyTagCellWidth ((PROPID) 0x0108)
#define PropertyTagCellHeight ((PROPID) 0x0109)
#define PropertyTagFillOrder ((PROPID) 0x010A)
#define PropertyTagDocumentName ((PROPID) 0x010D)
#define PropertyTagImageDescription ((PROPID) 0x010E)
#define PropertyTagEquipMake ((PROPID) 0x010F)
#define PropertyTagEquipModel ((PROPID) 0x0110)
#define PropertyTagStripOffsets ((PROPID) 0x0111)
#define PropertyTagOrientation ((PROPID) 0x0112)
#define PropertyTagSamplesPerPixel ((PROPID) 0x0115)
#define PropertyTagRowsPerStrip ((PROPID) 0x0116)
#define PropertyTagStripBytesCount ((PROPID) 0x0117)
#define PropertyTagMinSampleValue ((PROPID) 0x0118)
#define PropertyTagMaxSampleValue ((PROPID) 0x0119)
#define PropertyTagXResolution ((PROPID) 0x011A)
#define PropertyTagYResolution ((PROPID) 0x011B)
#define PropertyTagPlanarConfig ((PROPID) 0x011C)
#define PropertyTagPageName ((PROPID) 0x011D)
#define PropertyTagXPosition ((PROPID) 0x011E)
#define PropertyTagYPosition ((PROPID) 0x011F)
#define PropertyTagFreeOffset ((PROPID) 0x0120)
#define PropertyTagFreeByteCounts ((PROPID) 0x0121)
#define PropertyTagGrayResponseUnit ((PROPID) 0x0122)
#define PropertyTagGrayResponseCurve ((PROPID) 0x0123)
#define PropertyTagT4Option ((PROPID) 0x0124)
#define PropertyTagT6Option ((PROPID) 0x0125)
#define PropertyTagResolutionUnit ((PROPID) 0x0128)
#define PropertyTagPageNumber ((PROPID) 0x0129)
#define PropertyTagTransferFunction ((PROPID) 0x012D)
#define PropertyTagSoftwareUsed ((PROPID) 0x0131)
#define PropertyTagDateTime ((PROPID) 0x0132)
#define PropertyTagArtist ((PROPID) 0x013B)
#define PropertyTagHostComputer ((PROPID) 0x013C)
#define PropertyTagPredictor ((PROPID) 0x013D)
#define PropertyTagWhitePoint ((PROPID) 0x013E)
#define PropertyTagPrimaryChromaticities ((PROPID) 0x013F)
#define PropertyTagColorMap ((PROPID) 0x0140)
#define PropertyTagHalftoneHints ((PROPID) 0x0141)
#define PropertyTagTileWidth ((PROPID) 0x0142)
#define PropertyTagTileLength ((PROPID) 0x0143)
#define PropertyTagTileOffset ((PROPID) 0x0144)
#define PropertyTagTileByteCounts ((PROPID) 0x0145)
#define PropertyTagInkSet ((PROPID) 0x014C)
#define PropertyTagInkNames ((PROPID) 0x014D)
#define PropertyTagNumberOfInks ((PROPID) 0x014E)
#define PropertyTagDotRange ((PROPID) 0x0150)
#define PropertyTagTargetPrinter ((PROPID) 0x0151)
#define PropertyTagExtraSamples ((PROPID) 0x0152)
#define PropertyTagSampleFormat ((PROPID) 0x0153)
#define PropertyTagSMinSampleValue ((PROPID) 0x0154)
#define PropertyTagSMaxSampleValue ((PROPID) 0x0155)
#define PropertyTagTransferRange ((PROPID) 0x0156)
#define PropertyTagJPEGProc ((PROPID) 0x0200)
#define PropertyTagJPEGInterFormat ((PROPID) 0x0201)
#define PropertyTagJPEGInterLength ((PROPID) 0x0202)
#define PropertyTagJPEGRestartInterval ((PROPID) 0x0203)
#define PropertyTagJPEGLosslessPredictors ((PROPID) 0x0205)
#define PropertyTagJPEGPointTransforms ((PROPID) 0x0206)
#define PropertyTagJPEGQTables ((PROPID) 0x0207)
#define PropertyTagJPEGDCTables ((PROPID) 0x0208)
#define PropertyTagJPEGACTables ((PROPID) 0x0209)
#define PropertyTagYCbCrCoefficients ((PROPID) 0x0211)
#define PropertyTagYCbCrSubsampling ((PROPID) 0x0212)
#define PropertyTagYCbCrPositioning ((PROPID) 0x0213)
#define PropertyTagREFBlackWhite ((PROPID) 0x0214)
#define PropertyTagGamma ((PROPID) 0x0301)
#define PropertyTagICCProfileDescriptor ((PROPID) 0x0302)
#define PropertyTagSRGBRenderingIntent ((PROPID) 0x0303)
#define PropertyTagImageTitle ((PROPID) 0x0320)
#define PropertyTagResolutionXUnit ((PROPID) 0x5001)
#define PropertyTagResolutionYUnit ((PROPID) 0x5002)
#define PropertyTagResolutionXLengthUnit ((PROPID) 0x5003)
#define PropertyTagResolutionYLengthUnit ((PROPID) 0x5004)
#define PropertyTagPrintFlags ((PROPID) 0x5005)
#define PropertyTagPrintFlagsVersion ((PROPID) 0x5006)
#define PropertyTagPrintFlagsCrop ((PROPID) 0x5007)
#define PropertyTagPrintFlagsBleedWidth ((PROPID) 0x5008)
#define PropertyTagPrintFlagsBleedWidthScale ((PROPID) 0x5009)
#define PropertyTagHalftoneLPI ((PROPID) 0x500A)
#define PropertyTagHalftoneLPIUnit ((PROPID) 0x500B)
#define PropertyTagHalftoneDegree ((PROPID) 0x500C)
#define PropertyTagHalftoneShape ((PROPID) 0x500D)
#define PropertyTagHalftoneMisc ((PROPID) 0x500E)
#define PropertyTagHalftoneScreen ((PROPID) 0x500F)
#define PropertyTagJPEGQuality ((PROPID) 0x5010)
#define PropertyTagGridSize ((PROPID) 0x5011)
#define PropertyTagThumbnailFormat ((PROPID) 0x5012)
#define PropertyTagThumbnailWidth ((PROPID) 0x5013)
#define PropertyTagThumbnailHeight ((PROPID) 0x5014)
#define PropertyTagThumbnailColorDepth ((PROPID) 0x5015)
#define PropertyTagThumbnailPlanes ((PROPID) 0x5016)
#define PropertyTagThumbnailRawBytes ((PROPID) 0x5017)
#define PropertyTagThumbnailSize ((PROPID) 0x5018)
#define PropertyTagThumbnailCompressedSize ((PROPID) 0x5019)
#define PropertyTagColorTransferFunction ((PROPID) 0x501A)
#define PropertyTagThumbnailData ((PROPID) 0x501B)
#define PropertyTagThumbnailImageWidth ((PROPID) 0x5020)
#define PropertyTagThumbnailImageHeight ((PROPID) 0x5021)
#define PropertyTagThumbnailBitsPerSample ((PROPID) 0x5022)
#define PropertyTagThumbnailCompression ((PROPID) 0x5023)
#define PropertyTagThumbnailPhotometricInterp ((PROPID) 0x5024)
#define PropertyTagThumbnailImageDescription ((PROPID) 0x5025)
#define PropertyTagThumbnailEquipMake ((PROPID) 0x5026)
#define PropertyTagThumbnailEquipModel ((PROPID) 0x5027)
#define PropertyTagThumbnailStripOffsets ((PROPID) 0x5028)
#define PropertyTagThumbnailOrientation ((PROPID) 0x5029)
#define PropertyTagThumbnailSamplesPerPixel ((PROPID) 0x502A)
#define PropertyTagThumbnailRowsPerStrip ((PROPID) 0x502B)
#define PropertyTagThumbnailStripBytesCount ((PROPID) 0x502C)
#define PropertyTagThumbnailResolutionX ((PROPID) 0x502D)
#define PropertyTagThumbnailResolutionY ((PROPID) 0x502E)
#define PropertyTagThumbnailPlanarConfig ((PROPID) 0x502F)
#define PropertyTagThumbnailResolutionUnit ((PROPID) 0x5030)
#define PropertyTagThumbnailTransferFunction ((PROPID) 0x5031)
#define PropertyTagThumbnailSoftwareUsed ((PROPID) 0x5032)
#define PropertyTagThumbnailDateTime ((PROPID) 0x5033)
#define PropertyTagThumbnailArtist ((PROPID) 0x5034)
#define PropertyTagThumbnailWhitePoint ((PROPID) 0x5035)
#define PropertyTagThumbnailPrimaryChromaticities ((PROPID) 0x5036)
#define PropertyTagThumbnailYCbCrCoefficients ((PROPID) 0x5037)
#define PropertyTagThumbnailYCbCrSubsampling ((PROPID) 0x5038)
#define PropertyTagThumbnailYCbCrPositioning ((PROPID) 0x5039)
#define PropertyTagThumbnailRefBlackWhite ((PROPID) 0x503A)
#define PropertyTagThumbnailCopyRight ((PROPID) 0x503B)
#define PropertyTagLuminanceTable ((PROPID) 0x5090)
#define PropertyTagChrominanceTable ((PROPID) 0x5091)
#define PropertyTagFrameDelay ((PROPID) 0x5100)
#define PropertyTagLoopCount ((PROPID) 0x5101)
#define PropertyTagGlobalPalette ((PROPID) 0x5102)
#define PropertyTagIndexBackground ((PROPID) 0x5103)
#define PropertyTagIndexTransparent ((PROPID) 0x5104)
#define PropertyTagPixelUnit ((PROPID) 0x5110)
#define PropertyTagPixelPerUnitX ((PROPID) 0x5111)
#define PropertyTagPixelPerUnitY ((PROPID) 0x5112)
#define PropertyTagPaletteHistogram ((PROPID) 0x5113)
#define PropertyTagCopyright ((PROPID) 0x8298)
#define PropertyTagExifExposureTime ((PROPID) 0x829A)
#define PropertyTagExifFNumber ((PROPID) 0x829D)
#define PropertyTagExifIFD ((PROPID) 0x8769)
#define PropertyTagICCProfile ((PROPID) 0x8773)
#define PropertyTagExifExposureProg ((PROPID) 0x8822)
#define PropertyTagExifSpectralSense ((PROPID) 0x8824)
#define PropertyTagGpsIFD ((PROPID) 0x8825)
#define PropertyTagExifISOSpeed ((PROPID) 0x8827)
#define PropertyTagExifOECF ((PROPID) 0x8828)
#define PropertyTagExifVer ((PROPID) 0x9000)
#define PropertyTagExifDTOrig ((PROPID) 0x9003)
#define PropertyTagExifDTDigitized ((PROPID) 0x9004)
#define PropertyTagExifCompConfig ((PROPID) 0x9101)
#define PropertyTagExifCompBPP ((PROPID) 0x9102)
#define PropertyTagExifShutterSpeed ((PROPID) 0x9201)
#define PropertyTagExifAperture ((PROPID) 0x9202)
#define PropertyTagExifBrightness ((PROPID) 0x9203)
#define PropertyTagExifExposureBias ((PROPID) 0x9204)
#define PropertyTagExifMaxAperture ((PROPID) 0x9205)
#define PropertyTagExifSubjectDist ((PROPID) 0x9206)
#define PropertyTagExifMeteringMode ((PROPID) 0x9207)
#define PropertyTagExifLightSource ((PROPID) 0x9208)
#define PropertyTagExifFlash ((PROPID) 0x9209)
#define PropertyTagExifFocalLength ((PROPID) 0x920A)
#define PropertyTagExifMakerNote ((PROPID) 0x927C)
#define PropertyTagExifUserComment ((PROPID) 0x9286)
#define PropertyTagExifDTSubsec ((PROPID) 0x9290)
#define PropertyTagExifDTOrigSS ((PROPID) 0x9291)
#define PropertyTagExifDTDigSS ((PROPID) 0x9292)
#define PropertyTagExifFPXVer ((PROPID) 0xA000)
#define PropertyTagExifColorSpace ((PROPID) 0xA001)
#define PropertyTagExifPixXDim ((PROPID) 0xA002)
#define PropertyTagExifPixYDim ((PROPID) 0xA003)
#define PropertyTagExifRelatedWav ((PROPID) 0xA004)
#define PropertyTagExifInterop ((PROPID) 0xA005)
#define PropertyTagExifFlashEnergy ((PROPID) 0xA20B)
#define PropertyTagExifSpatialFR ((PROPID) 0xA20C)
#define PropertyTagExifFocalXRes ((PROPID) 0xA20E)
#define PropertyTagExifFocalYRes ((PROPID) 0xA20F)
#define PropertyTagExifFocalResUnit ((PROPID) 0xA210)
#define PropertyTagExifSubjectLoc ((PROPID) 0xA214)
#define PropertyTagExifExposureIndex ((PROPID) 0xA215)
#define PropertyTagExifSensingMethod ((PROPID) 0xA217)
#define PropertyTagExifFileSource ((PROPID) 0xA300)
#define PropertyTagExifSceneType ((PROPID) 0xA301)
#define PropertyTagExifCfaPattern ((PROPID) 0xA302)

#define PropertyTagTypeByte ((WORD) 1)
#define PropertyTagTypeASCII ((WORD) 2)
#define PropertyTagTypeShort ((WORD) 3)
#define PropertyTagTypeLong ((WORD) 4)
#define PropertyTagTypeRational ((WORD) 5)
#define PropertyTagTypeUndefined ((WORD) 7)
#define PropertyTagTypeSLONG ((WORD) 9)
#define PropertyTagTypeSRational ((WORD) 10)

#ifdef __cplusplus
extern "C" {
#endif

extern const GUID EncoderChrominanceTable;   /* f2e455dc-09b3-4316-8260-676ada32481c */
extern const GUID EncoderColorDepth;         /* 66087055-ad66-4c7c-9a18-38a2310b8337 */
extern const GUID EncoderColorSpace;         /* ? */
extern const GUID EncoderCompression;        /* e09d739d-ccd4-44ee-8eba-3fbf8be4fc58 */
extern const GUID EncoderImageItems;         /* ? */
extern const GUID EncoderLuminanceTable;     /* edb33bce-0266-4a77-b904-27216099e717 */
extern const GUID EncoderQuality;            /* 1d5be4b5-fa4a-452d-9cdd-5db35105e7eb */
extern const GUID EncoderRenderMethod;       /* 6d42c53a-229a-4825-8bb7-5c99e2b9a8b8 */
extern const GUID EncoderSaveAsCMYK;         /* ? */
extern const GUID EncoderSaveFlag;           /* 292266fc-ac40-47bf-8cfc-a85b89a655de */
extern const GUID EncoderScanMethod;         /* 3a4e2661-3109-4e56-8536-42c156e7dcfa */
extern const GUID EncoderTransformation;     /* 8d0eb2d1-a58e-4ea8-aa14-108074b7b6f9 */
extern const GUID EncoderVersion;            /* 24d18c76-814a-41a4-bf53-1c219cccf797 */

extern const GUID ImageFormatBMP;            /* b96b3cab-0728-11d3-9d7b-0000f81ef32e */
extern const GUID ImageFormatEMF;            /* b96b3cac-0728-11d3-9d7b-0000f81ef32e */
extern const GUID ImageFormatEXIF;           /* ? */
extern const GUID ImageFormatGIF;            /* b96b3cb0-0728-11d3-9d7b-0000f81ef32e */
extern const GUID ImageFormatIcon;           /* b96b3cb5-0728-11d3-9d7b-0000f81ef32e */
extern const GUID ImageFormatJPEG;           /* b96b3cae-0728-11d3-9d7b-0000f81ef32e */
extern const GUID ImageFormatMemoryBMP;      /* b96b3caa-0728-11d3-9d7b-0000f81ef32e */
extern const GUID ImageFormatPNG;            /* b96b3caf-0728-11d3-9d7b-0000f81ef32e */
extern const GUID ImageFormatTIFF;           /* b96b3cb1-0728-11d3-9d7b-0000f81ef32e */
extern const GUID ImageFormatUndefined;      /* ? */
extern const GUID ImageFormatWMF;            /* b96b3cad-0728-11d3-9d7b-0000f81ef32e */

extern const GUID FrameDimensionPage;        /* 7462dc86-6180-4c7e-8e3f-ee7333a7a483 */
extern const GUID FrameDimensionResolution;  /* ? */
extern const GUID FrameDimensionTime;        /* 6aedbd6d-3fb5-418a-83a6-7f45229dc872 */

#ifdef __cplusplus
}  /* extern "C" */
#endif

#endif /* __GDIPLUS_IMAGING_H */
