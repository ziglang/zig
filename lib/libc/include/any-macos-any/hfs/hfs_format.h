/*
 * Copyright (c) 2000-2015 Apple Inc. All rights reserved.
 *
 * @APPLE_OSREFERENCE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. The rights granted to you under the License
 * may not be used to create, or enable the creation or redistribution of,
 * unlawful or unlicensed copies of an Apple operating system, or to
 * circumvent, violate, or enable the circumvention or violation of, any
 * terms of an Apple operating system software license agreement.
 * 
 * Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_OSREFERENCE_LICENSE_HEADER_END@
 */
#ifndef __HFS_FORMAT__
#define __HFS_FORMAT__

#include <sys/types.h>
#include <sys/appleapiopts.h>
#include "hfs_unistr.h"

/*
 * hfs_format.h
 *
 * This file describes the on-disk format for HFS and HFS Plus volumes.
 *
 * Note: Starting 10.9, definition of struct HFSUniStr255 exists in hfs_unitstr.h
 *
 */

#ifdef __cplusplus
extern "C" {
#endif

/* some on-disk hfs structures have 68K alignment (misaligned) */

/* Signatures used to differentiate between HFS and HFS Plus volumes */
enum {
	kHFSSigWord		= 0x4244,	/* 'BD' in ASCII */
	kHFSPlusSigWord		= 0x482B,	/* 'H+' in ASCII */
	kHFSXSigWord		= 0x4858,	/* 'HX' in ASCII */

	kHFSPlusVersion		= 0x0004,	/* 'H+' volumes are version 4 only */
	kHFSXVersion		= 0x0005,	/* 'HX' volumes start with version 5 */

	kHFSPlusMountVersion	= 0x31302E30,	/* '10.0' for Mac OS X */
	kHFSJMountVersion	= 0x4846534a,	/* 'HFSJ' for journaled HFS+ on OS X */
	kFSKMountVersion	= 0x46534b21	/* 'FSK!' for failed journal replay */
};


#ifdef __APPLE_API_PRIVATE
/*
 * Mac OS X has two special directories on HFS+ volumes for hardlinked files
 * and hardlinked directories as well as for open-unlinked files.
 *
 * These directories and their contents are not exported from the filesystem
 * under Mac OS X.
 */
#define HFSPLUSMETADATAFOLDER       "\xE2\x90\x80\xE2\x90\x80\xE2\x90\x80\xE2\x90\x80HFS+ Private Data"
#define HFSPLUS_DIR_METADATA_FOLDER ".HFS+ Private Directory Data\xd"

/*
 * Files in the "HFS+ Private Data" folder have one of the following prefixes
 * followed by a decimal number (no leading zeros) for the file ID.
 *
 * Note: Earlier version of Mac OS X used a 32 bit random number for the link
 * ref number instead of the file id.
 *
 * e.g.  iNode7182000 and temp3296
 */
#define HFS_INODE_PREFIX	"iNode"
#define HFS_DELETE_PREFIX	"temp"

/*
 * Files in the ".HFS+ Private Directory Data" folder have the following 
 * prefix followed by a decimal number (no leading zeros) for the file ID.
 *
 * e.g. dir_555
 */
#define HFS_DIRINODE_PREFIX	"dir_"

/*
 * Hardlink inodes save the head of the link chain in
 * an extended attribute named FIRST_LINK_XATTR_NAME.
 * The attribute data is the decimal value in ASCII
 * of the cnid for the first link in the chain.
 *
 * This extended attribute is private (i.e. its not
 * exported in the getxattr/listxattr POSIX APIs).
 */
#define FIRST_LINK_XATTR_NAME	"com.apple.system.hfs.firstlink"
#define FIRST_LINK_XATTR_REC_SIZE (sizeof(HFSPlusAttrData) - 2 + 12)

/*
 * The name space ID for generating an HFS volume UUID
 *
 * B3E20F39-F292-11D6-97A4-00306543ECAC
 */
#define HFS_UUID_NAMESPACE_ID  "\xB3\xE2\x0F\x39\xF2\x92\x11\xD6\x97\xA4\x00\x30\x65\x43\xEC\xAC"

#endif /* __APPLE_API_PRIVATE */

/*
 * Indirect link files (hard links) have the following type/creator.
 */
enum {
	kHardLinkFileType = 0x686C6E6B,  /* 'hlnk' */
	kHFSPlusCreator   = 0x6866732B   /* 'hfs+' */
};


/*
 *	File type and creator for symbolic links
 */
enum {
      kSymLinkFileType  = 0x736C6E6B, /* 'slnk' */
      kSymLinkCreator   = 0x72686170  /* 'rhap' */
};


enum {
	kHFSMaxVolumeNameChars		= 27,
	kHFSMaxFileNameChars		= 31,
	kHFSPlusMaxFileNameChars	= 255
};


/* Extent overflow file data structures */

/* HFS Extent key */
struct HFSExtentKey {
	u_int8_t 	keyLength;	/* length of key, excluding this field */
	u_int8_t 	forkType;	/* 0 = data fork, FF = resource fork */
	u_int32_t 	fileID;		/* file ID */
	u_int16_t 	startBlock;	/* first file allocation block number in this extent */
} __attribute__((aligned(2), packed));
typedef struct HFSExtentKey HFSExtentKey;

/* HFS Plus Extent key */
struct HFSPlusExtentKey {
	u_int16_t 	keyLength;		/* length of key, excluding this field */
	u_int8_t 	forkType;		/* 0 = data fork, FF = resource fork */
	u_int8_t 	pad;			/* make the other fields align on 32-bit boundary */
	u_int32_t 	fileID;			/* file ID */
	u_int32_t 	startBlock;		/* first file allocation block number in this extent */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusExtentKey HFSPlusExtentKey;

/* Number of extent descriptors per extent record */
enum {
	kHFSExtentDensity	= 3,
	kHFSPlusExtentDensity	= 8
};

/* HFS extent descriptor */
struct HFSExtentDescriptor {
	u_int16_t 	startBlock;		/* first allocation block */
	u_int16_t 	blockCount;		/* number of allocation blocks */
} __attribute__((aligned(2), packed));
typedef struct HFSExtentDescriptor HFSExtentDescriptor;

/* HFS Plus extent descriptor */
struct HFSPlusExtentDescriptor {
	u_int32_t 	startBlock;		/* first allocation block */
	u_int32_t 	blockCount;		/* number of allocation blocks */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusExtentDescriptor HFSPlusExtentDescriptor;

/* HFS extent record */
typedef HFSExtentDescriptor HFSExtentRecord[3];

/* HFS Plus extent record */
typedef HFSPlusExtentDescriptor HFSPlusExtentRecord[8];


/* Finder information */
struct FndrFileInfo {
	u_int32_t 	fdType;		/* file type */
	u_int32_t 	fdCreator;	/* file creator */
	u_int16_t 	fdFlags;	/* Finder flags */
	struct {
	    int16_t	v;		/* file's location */
	    int16_t	h;
	} fdLocation;
	int16_t 	opaque;
} __attribute__((aligned(2), packed));
typedef struct FndrFileInfo FndrFileInfo;

struct FndrDirInfo {
	struct {			/* folder's window rectangle */
	    int16_t	top;
	    int16_t	left;
	    int16_t	bottom;
	    int16_t	right;
	} frRect;
	unsigned short 	frFlags;	/* Finder flags */
	struct {
	    u_int16_t	v;		/* folder's location */
	    u_int16_t	h;
	} frLocation;
	int16_t 	opaque;
} __attribute__((aligned(2), packed));
typedef struct FndrDirInfo FndrDirInfo;

struct FndrOpaqueInfo {
	int8_t opaque[16];
} __attribute__((aligned(2), packed));
typedef struct FndrOpaqueInfo FndrOpaqueInfo;

struct FndrExtendedDirInfo {
	u_int32_t document_id;
	u_int32_t date_added;
	u_int16_t extended_flags;
	u_int16_t reserved3;
	u_int32_t write_gen_counter;
} __attribute__((aligned(2), packed));

struct FndrExtendedFileInfo {
	u_int32_t document_id;
	u_int32_t date_added;
	u_int16_t extended_flags;
	u_int16_t reserved2;
	u_int32_t write_gen_counter;
} __attribute__((aligned(2), packed));

/* HFS Plus Fork data info - 80 bytes */
struct HFSPlusForkData {
	u_int64_t 		logicalSize;	/* fork's logical size in bytes */
	u_int32_t 		clumpSize;	/* fork's clump size in bytes */
	u_int32_t 		totalBlocks;	/* total blocks used by this fork */
	HFSPlusExtentRecord 	extents;	/* initial set of extents */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusForkData HFSPlusForkData;


/* Mac OS X has 16 bytes worth of "BSD" info.
 *
 * Note:  Mac OS 9 implementations and applications
 * should preserve, but not change, this information.
 */
struct HFSPlusBSDInfo {
	u_int32_t 	ownerID;	/* user-id of owner or hard link chain previous link */
	u_int32_t 	groupID;	/* group-id of owner or hard link chain next link */
	u_int8_t 	adminFlags;	/* super-user changeable flags */
	u_int8_t 	ownerFlags;	/* owner changeable flags */
	u_int16_t 	fileMode;	/* file type and permission bits */
	union {
	    u_int32_t	iNodeNum;	/* indirect node number (hard links only) */
	    u_int32_t	linkCount;	/* links that refer to this indirect node */
	    u_int32_t	rawDevice;	/* special file device (FBLK and FCHR only) */
	} special;
} __attribute__((aligned(2), packed));
typedef struct HFSPlusBSDInfo HFSPlusBSDInfo;

/*
 * Hardlink "links" resolve to an inode
 * and the actual uid/gid comes from that
 * inode.
 *
 * We repurpose the links's uid/gid fields
 * for the hardlink link chain. The chain
 * consists of a doubly linked list of file
 * ids.
 */
 
#define hl_firstLinkID     reserved1         /* Valid only if HasLinkChain flag is set (indirect nodes only) */

#define hl_prevLinkID      bsdInfo.ownerID   /* Valid only if HasLinkChain flag is set */
#define hl_nextLinkID      bsdInfo.groupID   /* Valid only if HasLinkChain flag is set */

#define hl_linkReference   bsdInfo.special.iNodeNum
#define hl_linkCount       bsdInfo.special.linkCount


/* Catalog file data structures */

enum {
	kHFSRootParentID		= 1,	/* Parent ID of the root folder */
	kHFSRootFolderID		= 2,	/* Folder ID of the root folder */
	kHFSExtentsFileID		= 3,	/* File ID of the extents file */
	kHFSCatalogFileID		= 4,	/* File ID of the catalog file */
	kHFSBadBlockFileID		= 5,	/* File ID of the bad allocation block file */
	kHFSAllocationFileID		= 6,	/* File ID of the allocation file (HFS Plus only) */
	kHFSStartupFileID		= 7,	/* File ID of the startup file (HFS Plus only) */
	kHFSAttributesFileID		= 8,	/* File ID of the attribute file (HFS Plus only) */
	kHFSAttributeDataFileID         = 13,	/* Used in Mac OS X runtime for extent based attributes */
	                                        /* kHFSAttributeDataFileID is never stored on disk. */
	kHFSRepairCatalogFileID		= 14,	/* Used when rebuilding Catalog B-tree */
	kHFSBogusExtentFileID		= 15,	/* Used for exchanging extents in extents file */
	kHFSFirstUserCatalogNodeID	= 16
};

/* HFS catalog key */
struct HFSCatalogKey {
	u_int8_t 	keyLength;		/* key length (in bytes) */
	u_int8_t 	reserved;		/* reserved (set to zero) */
	u_int32_t 	parentID;		/* parent folder ID */
	u_int8_t 	nodeName[kHFSMaxFileNameChars + 1]; /* catalog node name */
} __attribute__((aligned(2), packed));
typedef struct HFSCatalogKey HFSCatalogKey;

/* HFS Plus catalog key */
struct HFSPlusCatalogKey {
	u_int16_t 		keyLength;	/* key length (in bytes) */
	u_int32_t 		parentID;	/* parent folder ID */
	HFSUniStr255 		nodeName;	/* catalog node name */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusCatalogKey HFSPlusCatalogKey;

/* Catalog record types */
enum {
	/* HFS Catalog Records */
	kHFSFolderRecord		= 0x0100,	/* Folder record */
	kHFSFileRecord			= 0x0200,	/* File record */
	kHFSFolderThreadRecord		= 0x0300,	/* Folder thread record */
	kHFSFileThreadRecord		= 0x0400,	/* File thread record */

	/* HFS Plus Catalog Records */
	kHFSPlusFolderRecord		= 1,		/* Folder record */
	kHFSPlusFileRecord		= 2,		/* File record */
	kHFSPlusFolderThreadRecord	= 3,		/* Folder thread record */
	kHFSPlusFileThreadRecord	= 4		/* File thread record */
};


/* Catalog file record flags */
enum {
	kHFSFileLockedBit	= 0x0000,	/* file is locked and cannot be written to */
	kHFSFileLockedMask	= 0x0001,

	kHFSThreadExistsBit	= 0x0001,	/* a file thread record exists for this file */
	kHFSThreadExistsMask	= 0x0002,

	kHFSHasAttributesBit	= 0x0002,	/* object has extended attributes */
	kHFSHasAttributesMask	= 0x0004,

	kHFSHasSecurityBit	= 0x0003,	/* object has security data (ACLs) */
	kHFSHasSecurityMask	= 0x0008,

	kHFSHasFolderCountBit	= 0x0004,	/* only for HFSX, folder maintains a separate sub-folder count */
	kHFSHasFolderCountMask	= 0x0010,	/* (sum of folder records and directory hard links) */

	kHFSHasLinkChainBit	= 0x0005,	/* has hardlink chain (inode or link) */
	kHFSHasLinkChainMask	= 0x0020,

	kHFSHasChildLinkBit	= 0x0006,	/* folder has a child that's a dir link */
	kHFSHasChildLinkMask	= 0x0040,

	kHFSHasDateAddedBit     = 0x0007,	/* File/Folder has the date-added stored in the finder info. */
	kHFSHasDateAddedMask    = 0x0080, 

	kHFSFastDevPinnedBit    = 0x0008,       /* this file has been pinned to the fast-device by the hot-file code on cooperative fusion */
	kHFSFastDevPinnedMask   = 0x0100,

	kHFSDoNotFastDevPinBit  = 0x0009,       /* this file can not be pinned to the fast-device */
	kHFSDoNotFastDevPinMask = 0x0200,

	kHFSFastDevCandidateBit  = 0x000a,      /* this item is a potential candidate for fast-dev pinning (as are any of its descendents */
	kHFSFastDevCandidateMask = 0x0400,

	kHFSAutoCandidateBit     = 0x000b,      /* this item was automatically marked as a fast-dev candidate by the kernel */
	kHFSAutoCandidateMask    = 0x0800

	// There are only 4 flag bits remaining: 0x1000, 0x2000, 0x4000, 0x8000

};


/* HFS catalog folder record - 70 bytes */
struct HFSCatalogFolder {
	int16_t 		recordType;		/* == kHFSFolderRecord */
	u_int16_t 		flags;			/* folder flags */
	u_int16_t 		valence;		/* folder valence */
	u_int32_t		folderID;		/* folder ID */
	u_int32_t 		createDate;		/* date and time of creation */
	u_int32_t 		modifyDate;		/* date and time of last modification */
	u_int32_t 		backupDate;		/* date and time of last backup */
	FndrDirInfo 		userInfo;		/* Finder information */
	FndrOpaqueInfo		finderInfo;		/* additional Finder information */
	u_int32_t 		reserved[4];		/* reserved - initialized as zero */
} __attribute__((aligned(2), packed));
typedef struct HFSCatalogFolder HFSCatalogFolder;

/* HFS Plus catalog folder record - 88 bytes */
struct HFSPlusCatalogFolder {
	int16_t 		recordType;		/* == kHFSPlusFolderRecord */
	u_int16_t 		flags;			/* file flags */
	u_int32_t 		valence;		/* folder's item count */
	u_int32_t 		folderID;		/* folder ID */
	u_int32_t 		createDate;		/* date and time of creation */
	u_int32_t 		contentModDate;		/* date and time of last content modification */
	u_int32_t 		attributeModDate;	/* date and time of last attribute modification */
	u_int32_t 		accessDate;		/* date and time of last access (MacOS X only) */
	u_int32_t 		backupDate;		/* date and time of last backup */
	HFSPlusBSDInfo		bsdInfo;		/* permissions (for MacOS X) */
	FndrDirInfo 		userInfo;		/* Finder information */
	FndrOpaqueInfo	 	finderInfo;		/* additional Finder information */
	u_int32_t 		textEncoding;		/* hint for name conversions */
	u_int32_t 		folderCount;		/* number of enclosed folders, active when HasFolderCount is set */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusCatalogFolder HFSPlusCatalogFolder;

/* HFS catalog file record - 102 bytes */
struct HFSCatalogFile {
	int16_t 		recordType;		/* == kHFSFileRecord */
	u_int8_t 		flags;			/* file flags */
	int8_t 			fileType;		/* file type (unused ?) */
	FndrFileInfo 		userInfo;		/* Finder information */
	u_int32_t 		fileID;			/* file ID */
	u_int16_t 		dataStartBlock;		/* not used - set to zero */
	int32_t 		dataLogicalSize;	/* logical EOF of data fork */
	int32_t 		dataPhysicalSize;	/* physical EOF of data fork */
	u_int16_t		rsrcStartBlock;		/* not used - set to zero */
	int32_t			rsrcLogicalSize;	/* logical EOF of resource fork */
	int32_t			rsrcPhysicalSize;	/* physical EOF of resource fork */
	u_int32_t		createDate;		/* date and time of creation */
	u_int32_t		modifyDate;		/* date and time of last modification */
	u_int32_t		backupDate;		/* date and time of last backup */
	FndrOpaqueInfo		finderInfo;		/* additional Finder information */
	u_int16_t		clumpSize;		/* file clump size (not used) */
	HFSExtentRecord		dataExtents;		/* first data fork extent record */
	HFSExtentRecord		rsrcExtents;		/* first resource fork extent record */
	u_int32_t		reserved;		/* reserved - initialized as zero */
} __attribute__((aligned(2), packed));
typedef struct HFSCatalogFile HFSCatalogFile;

/* HFS Plus catalog file record - 248 bytes */
struct HFSPlusCatalogFile {
	int16_t 		recordType;		/* == kHFSPlusFileRecord */
	u_int16_t 		flags;			/* file flags */
	u_int32_t 		reserved1;		/* reserved - initialized as zero */
	u_int32_t 		fileID;			/* file ID */
	u_int32_t 		createDate;		/* date and time of creation */
	u_int32_t 		contentModDate;		/* date and time of last content modification */
	u_int32_t 		attributeModDate;	/* date and time of last attribute modification */
	u_int32_t 		accessDate;		/* date and time of last access (MacOS X only) */
	u_int32_t 		backupDate;		/* date and time of last backup */
	HFSPlusBSDInfo 		bsdInfo;		/* permissions (for MacOS X) */
	FndrFileInfo 		userInfo;		/* Finder information */
	FndrOpaqueInfo	 	finderInfo;		/* additional Finder information */
	u_int32_t 		textEncoding;		/* hint for name conversions */
	u_int32_t 		reserved2;		/* reserved - initialized as zero */

	/* Note: these start on double long (64 bit) boundary */
	HFSPlusForkData 	dataFork;		/* size and block data for data fork */
	HFSPlusForkData 	resourceFork;		/* size and block data for resource fork */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusCatalogFile HFSPlusCatalogFile;

/* HFS catalog thread record - 46 bytes */
struct HFSCatalogThread {
	int16_t 	recordType;		/* == kHFSFolderThreadRecord or kHFSFileThreadRecord */
	int32_t 	reserved[2];		/* reserved - initialized as zero */
	u_int32_t 	parentID;		/* parent ID for this catalog node */
	u_int8_t 	nodeName[kHFSMaxFileNameChars + 1]; /* name of this catalog node */
} __attribute__((aligned(2), packed));
typedef struct HFSCatalogThread HFSCatalogThread;

/* HFS Plus catalog thread record -- 264 bytes */
struct HFSPlusCatalogThread {
	int16_t 	recordType;		/* == kHFSPlusFolderThreadRecord or kHFSPlusFileThreadRecord */
	int16_t 	reserved;		/* reserved - initialized as zero */
	u_int32_t 	parentID;		/* parent ID for this catalog node */
	HFSUniStr255 	nodeName;		/* name of this catalog node (variable length) */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusCatalogThread HFSPlusCatalogThread;

#ifdef __APPLE_API_UNSTABLE
/*
 * 	These are the types of records in the attribute B-tree.  The values were
 * 	chosen so that they wouldn't conflict with the catalog record types.
 */
enum {
	kHFSPlusAttrInlineData	= 0x10,   /* attributes whose data fits in a b-tree node */
	kHFSPlusAttrForkData	= 0x20,   /* extent based attributes (data lives in extents) */
	kHFSPlusAttrExtents	= 0x30    /* overflow extents for large attributes */
};


/*
 *  	HFSPlusAttrForkData
 * 	For larger attributes, whose value is stored in allocation blocks.
 * 	If the attribute has more than 8 extents, there will be additional
 * 	records (of type HFSPlusAttrExtents) for this attribute.
 */
struct HFSPlusAttrForkData {
	u_int32_t 	recordType;		/* == kHFSPlusAttrForkData*/
	u_int32_t 	reserved;
	HFSPlusForkData theFork;		/* size and first extents of value*/
} __attribute__((aligned(2), packed));
typedef struct HFSPlusAttrForkData HFSPlusAttrForkData;

/*
 * 	HFSPlusAttrExtents
 * 	This record contains information about overflow extents for large,
 * 	fragmented attributes.
 */
struct HFSPlusAttrExtents {
	u_int32_t 		recordType;	/* == kHFSPlusAttrExtents*/
	u_int32_t 		reserved;
	HFSPlusExtentRecord	extents;	/* additional extents*/
} __attribute__((aligned(2), packed));
typedef struct HFSPlusAttrExtents HFSPlusAttrExtents;

/*
 * Atrributes B-tree Data Record
 *
 * For small attributes, whose entire value is stored
 * within a single B-tree record.
 */
struct HFSPlusAttrData {
	u_int32_t    recordType;   /* == kHFSPlusAttrInlineData */
	u_int32_t    reserved[2];
	u_int32_t    attrSize;     /* size of attribute data in bytes */
	u_int8_t     attrData[2];  /* variable length */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusAttrData HFSPlusAttrData;


/* HFSPlusAttrInlineData is obsolete use HFSPlusAttrData instead */
struct HFSPlusAttrInlineData {
	u_int32_t 	recordType;
	u_int32_t 	reserved;
	u_int32_t 	logicalSize;
	u_int8_t 	userData[2];
} __attribute__((aligned(2), packed));
typedef struct HFSPlusAttrInlineData HFSPlusAttrInlineData;


/* A generic Attribute Record */
union HFSPlusAttrRecord {
	u_int32_t 		recordType;
	HFSPlusAttrInlineData 	inlineData;   /* NOT USED */
	HFSPlusAttrData 	attrData;
	HFSPlusAttrForkData 	forkData;
	HFSPlusAttrExtents 	overflowExtents;
};
typedef union HFSPlusAttrRecord HFSPlusAttrRecord;

/* Attribute key */
enum { kHFSMaxAttrNameLen = 127 };
struct HFSPlusAttrKey {
	u_int16_t     keyLength;       /* key length (in bytes) */
	u_int16_t     pad;	       /* set to zero */
	u_int32_t     fileID;          /* file associated with attribute */
	u_int32_t     startBlock;      /* first allocation block number for extents */
	u_int16_t     attrNameLen;     /* number of unicode characters */
	u_int16_t     attrName[kHFSMaxAttrNameLen];   /* attribute name (Unicode) */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusAttrKey HFSPlusAttrKey;

#define kHFSPlusAttrKeyMaximumLength   (sizeof(HFSPlusAttrKey) - sizeof(u_int16_t))
#define kHFSPlusAttrKeyMinimumLength   (kHFSPlusAttrKeyMaximumLength - kHFSMaxAttrNameLen*sizeof(u_int16_t))

#endif /* __APPLE_API_UNSTABLE */


/* Key and node lengths */
enum {
	kHFSPlusExtentKeyMaximumLength = sizeof(HFSPlusExtentKey) - sizeof(u_int16_t),
	kHFSExtentKeyMaximumLength	= sizeof(HFSExtentKey) - sizeof(u_int8_t),
	kHFSPlusCatalogKeyMaximumLength = sizeof(HFSPlusCatalogKey) - sizeof(u_int16_t),
	kHFSPlusCatalogKeyMinimumLength = kHFSPlusCatalogKeyMaximumLength - sizeof(HFSUniStr255) + sizeof(u_int16_t),
	kHFSCatalogKeyMaximumLength	= sizeof(HFSCatalogKey) - sizeof(u_int8_t),
	kHFSCatalogKeyMinimumLength	= kHFSCatalogKeyMaximumLength - (kHFSMaxFileNameChars + 1) + sizeof(u_int8_t),
	kHFSPlusCatalogMinNodeSize	= 4096,
	kHFSPlusExtentMinNodeSize	= 512,
	kHFSPlusAttrMinNodeSize		= 4096
};

/* HFS and HFS Plus volume attribute bits */
enum {
	/* Bits 0-6 are reserved (always cleared by MountVol call) */
	kHFSVolumeHardwareLockBit	= 7,		/* volume is locked by hardware */
	kHFSVolumeUnmountedBit		= 8,		/* volume was successfully unmounted */
	kHFSVolumeSparedBlocksBit	= 9,		/* volume has bad blocks spared */
	kHFSVolumeNoCacheRequiredBit = 10,		/* don't cache volume blocks (i.e. RAM or ROM disk) */
	kHFSBootVolumeInconsistentBit = 11,		/* boot volume is inconsistent (System 7.6 and later) */
	kHFSCatalogNodeIDsReusedBit = 12,
	kHFSVolumeJournaledBit = 13,			/* this volume has a journal on it */
	kHFSVolumeInconsistentBit = 14,			/* serious inconsistencies detected at runtime */
	kHFSVolumeSoftwareLockBit	= 15,		/* volume is locked by software */
	/*
	 * HFS only has 16 bits of attributes in the MDB, but HFS Plus has 32 bits.
	 * Therefore, bits 16-31 can only be used on HFS Plus.
	 */
	kHFSUnusedNodeFixBit = 31,				/* Unused nodes in the Catalog B-tree have been zero-filled.  See Radar #6947811. */
	kHFSContentProtectionBit = 30,			/* Volume has per-file content protection */

	/***  Keep these in sync with the bits above ! ****/
	kHFSVolumeHardwareLockMask		= 0x00000080,
	kHFSVolumeUnmountedMask			= 0x00000100,
	kHFSVolumeSparedBlocksMask		= 0x00000200,
	kHFSVolumeNoCacheRequiredMask 	= 0x00000400,
	kHFSBootVolumeInconsistentMask	= 0x00000800,
	kHFSCatalogNodeIDsReusedMask 	= 0x00001000,
	kHFSVolumeJournaledMask			= 0x00002000,
	kHFSVolumeInconsistentMask 		= 0x00004000,
	kHFSVolumeSoftwareLockMask		= 0x00008000,
	
	/* Bits 16-31 are allocated from high to low */

	kHFSContentProtectionMask 		= 0x40000000,
	kHFSUnusedNodeFixMask 			= 0x80000000,
	
	kHFSMDBAttributesMask			= 0x8380
};

enum {
	kHFSUnusedNodesFixDate = 0xc5ef2480		/* March 25, 2009 */
};

/* HFS Master Directory Block - 162 bytes */
/* Stored at sector #2 (3rd sector) and second-to-last sector. */
struct HFSMasterDirectoryBlock {
	u_int16_t 		drSigWord;	/* == kHFSSigWord */
	u_int32_t 		drCrDate;	/* date and time of volume creation */
	u_int32_t 		drLsMod;	/* date and time of last modification */
	u_int16_t 		drAtrb;		/* volume attributes */
	u_int16_t 		drNmFls;	/* number of files in root folder */
	u_int16_t 		drVBMSt;	/* first block of volume bitmap */
	u_int16_t 		drAllocPtr;	/* start of next allocation search */
	u_int16_t 		drNmAlBlks;	/* number of allocation blocks in volume */
	u_int32_t 		drAlBlkSiz;	/* size (in bytes) of allocation blocks */
	u_int32_t 		drClpSiz;	/* default clump size */
	u_int16_t 		drAlBlSt;	/* first allocation block in volume */
	u_int32_t 		drNxtCNID;	/* next unused catalog node ID */
	u_int16_t 		drFreeBks;	/* number of unused allocation blocks */
	u_int8_t 		drVN[kHFSMaxVolumeNameChars + 1];  /* volume name */
	u_int32_t 		drVolBkUp;	/* date and time of last backup */
	u_int16_t 		drVSeqNum;	/* volume backup sequence number */
	u_int32_t 		drWrCnt;	/* volume write count */
	u_int32_t 		drXTClpSiz;	/* clump size for extents overflow file */
	u_int32_t 		drCTClpSiz;	/* clump size for catalog file */
	u_int16_t 		drNmRtDirs;	/* number of directories in root folder */
	u_int32_t 		drFilCnt;	/* number of files in volume */
	u_int32_t 		drDirCnt;	/* number of directories in volume */
	u_int32_t 		drFndrInfo[8];	/* information used by the Finder */
	u_int16_t 		drEmbedSigWord;	/* embedded volume signature (formerly drVCSize) */
	HFSExtentDescriptor	drEmbedExtent;	/* embedded volume location and size (formerly drVBMCSize and drCtlCSize) */
	u_int32_t		drXTFlSize;	/* size of extents overflow file */
	HFSExtentRecord		drXTExtRec;	/* extent record for extents overflow file */
	u_int32_t 		drCTFlSize;	/* size of catalog file */
	HFSExtentRecord 	drCTExtRec;	/* extent record for catalog file */
} __attribute__((aligned(2), packed));
typedef struct HFSMasterDirectoryBlock	HFSMasterDirectoryBlock;


#ifdef __APPLE_API_UNSTABLE
#define SET_HFS_TEXT_ENCODING(hint)  \
	(0x656e6300 | ((hint) & 0xff))
#define GET_HFS_TEXT_ENCODING(hint)  \
	(((hint) & 0xffffff00) == 0x656e6300 ? (hint) & 0x000000ff : 0xffffffffU)
#endif /* __APPLE_API_UNSTABLE */


/* HFS Plus Volume Header - 512 bytes */
/* Stored at sector #2 (3rd sector) and second-to-last sector. */
struct HFSPlusVolumeHeader {
	u_int16_t 	signature;		/* == kHFSPlusSigWord */
	u_int16_t 	version;		/* == kHFSPlusVersion */
	u_int32_t 	attributes;		/* volume attributes */
	u_int32_t 	lastMountedVersion;	/* implementation version which last mounted volume */
	u_int32_t 	journalInfoBlock;	/* block addr of journal info (if volume is journaled, zero otherwise) */

	u_int32_t 	createDate;		/* date and time of volume creation */
	u_int32_t 	modifyDate;		/* date and time of last modification */
	u_int32_t 	backupDate;		/* date and time of last backup */
	u_int32_t 	checkedDate;		/* date and time of last disk check */

	u_int32_t 	fileCount;		/* number of files in volume */
	u_int32_t 	folderCount;		/* number of directories in volume */

	u_int32_t 	blockSize;		/* size (in bytes) of allocation blocks */
	u_int32_t 	totalBlocks;		/* number of allocation blocks in volume (includes this header and VBM*/
	u_int32_t 	freeBlocks;		/* number of unused allocation blocks */

	u_int32_t 	nextAllocation;		/* start of next allocation search */
	u_int32_t 	rsrcClumpSize;		/* default resource fork clump size */
	u_int32_t 	dataClumpSize;		/* default data fork clump size */
	u_int32_t 	nextCatalogID;		/* next unused catalog node ID */

	u_int32_t 	writeCount;		/* volume write count */
	u_int64_t 	encodingsBitmap;	/* which encodings have been use  on this volume */

	u_int8_t 	finderInfo[32];		/* information used by the Finder */

	HFSPlusForkData	 allocationFile;	/* allocation bitmap file */
	HFSPlusForkData  extentsFile;		/* extents B-tree file */
	HFSPlusForkData  catalogFile;		/* catalog B-tree file */
	HFSPlusForkData  attributesFile;	/* extended attributes B-tree file */
	HFSPlusForkData	 startupFile;		/* boot file (secondary loader) */
} __attribute__((aligned(2), packed));
typedef struct HFSPlusVolumeHeader HFSPlusVolumeHeader;


/* B-tree structures */

enum BTreeKeyLimits{
	kMaxKeyLength	= 520
};

union BTreeKey{
	u_int8_t	length8;
	u_int16_t	length16;
	u_int8_t	rawData [kMaxKeyLength+2];
};
typedef union BTreeKey BTreeKey;

/* BTNodeDescriptor -- Every B-tree node starts with these fields. */
struct BTNodeDescriptor {
	u_int32_t	fLink;			/* next node at this level*/
	u_int32_t 	bLink;			/* previous node at this level*/
	int8_t 		kind;			/* kind of node (leaf, index, header, map)*/
	u_int8_t 	height;			/* zero for header, map; child is one more than parent*/
	u_int16_t 	numRecords;		/* number of records in this node*/
	u_int16_t 	reserved;		/* reserved - initialized as zero */
} __attribute__((aligned(2), packed));
typedef struct BTNodeDescriptor BTNodeDescriptor;

/* Constants for BTNodeDescriptor kind */
enum {
	kBTLeafNode	= -1,
	kBTIndexNode	= 0,
	kBTHeaderNode	= 1,
	kBTMapNode	= 2
};

/* BTHeaderRec -- The first record of a B-tree header node */
struct BTHeaderRec {
	u_int16_t	treeDepth;		/* maximum height (usually leaf nodes) */
	u_int32_t 	rootNode;		/* node number of root node */
	u_int32_t 	leafRecords;		/* number of leaf records in all leaf nodes */
	u_int32_t 	firstLeafNode;		/* node number of first leaf node */
	u_int32_t 	lastLeafNode;		/* node number of last leaf node */
	u_int16_t 	nodeSize;		/* size of a node, in bytes */
	u_int16_t 	maxKeyLength;		/* reserved */
	u_int32_t 	totalNodes;		/* total number of nodes in tree */
	u_int32_t 	freeNodes;		/* number of unused (free) nodes in tree */
	u_int16_t 	reserved1;		/* unused */
	u_int32_t 	clumpSize;		/* reserved */
	u_int8_t 	btreeType;		/* reserved */
	u_int8_t 	keyCompareType;		/* Key string Comparison Type */
	u_int32_t 	attributes;		/* persistent attributes about the tree */
	u_int32_t 	reserved3[16];		/* reserved */
} __attribute__((aligned(2), packed));
typedef struct BTHeaderRec BTHeaderRec;

/* Constants for BTHeaderRec attributes */
enum {
	kBTBadCloseMask		 = 0x00000001,	/* reserved */
	kBTBigKeysMask		 = 0x00000002,	/* key length field is 16 bits */
	kBTVariableIndexKeysMask = 0x00000004	/* keys in index nodes are variable length */
};


/* Catalog Key Name Comparison Type */
enum {
	kHFSCaseFolding   = 0xCF,  /* case folding (case-insensitive) */
	kHFSBinaryCompare = 0xBC  /* binary compare (case-sensitive) */
};

#ifdef __cplusplus
}
#endif

#include <uuid/uuid.h>

#ifdef __cplusplus
extern "C" {
#endif

/* JournalInfoBlock - Structure that describes where our journal lives */

// the original size of the reserved field in the JournalInfoBlock was
// 32*sizeof(u_int32_t).  To keep the total size of the structure the 
// same we subtract the size of new fields (currently: ext_jnl_uuid and
// machine_uuid).  If you add additional fields, place them before the
// reserved field and subtract their size in this macro.
//
#define JIB_RESERVED_SIZE  ((32*sizeof(u_int32_t)) - sizeof(uuid_string_t) - 48)

struct JournalInfoBlock {
	u_int32_t	flags;
    	u_int32_t       device_signature[8];  // signature used to locate our device.
	u_int64_t       offset;               // byte offset to the journal on the device
	u_int64_t       size;                 // size in bytes of the journal
	uuid_string_t   ext_jnl_uuid;
	char            machine_serial_num[48];
	char    	reserved[JIB_RESERVED_SIZE];
} __attribute__((aligned(2), packed));
typedef struct JournalInfoBlock JournalInfoBlock;

enum {
    kJIJournalInFSMask          = 0x00000001,
    kJIJournalOnOtherDeviceMask = 0x00000002,
    kJIJournalNeedInitMask      = 0x00000004
};

//
// This the content type uuid for "external journal" GPT 
// partitions.  Each instance of a partition also has a
// uuid that uniquely identifies that instance.
//
#define EXTJNL_CONTENT_TYPE_UUID "4A6F7572-6E61-11AA-AA11-00306543ECAC"


#ifdef __cplusplus
}
#endif

#endif /* __HFS_FORMAT__ */
