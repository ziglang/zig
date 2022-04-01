
from zipfile import ZIP_STORED, ZIP_DEFLATED
from rpython.rlib.streamio import open_file_as_stream
from rpython.rlib.rstruct.runpack import runpack
from rpython.rlib.rarithmetic import r_uint, intmask
from rpython.rtyper.tool.rffi_platform import CompilationError
import os

try:
    from rpython.rlib import rzlib
except CompilationError:
    rzlib = None

crc_32_tab = [
    0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419,
    0x706af48f, 0xe963a535, 0x9e6495a3, 0x0edb8832, 0x79dcb8a4,
    0xe0d5e91e, 0x97d2d988, 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07,
    0x90bf1d91, 0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de,
    0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7, 0x136c9856,
    0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9,
    0xfa0f3d63, 0x8d080df5, 0x3b6e20c8, 0x4c69105e, 0xd56041e4,
    0xa2677172, 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
    0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3,
    0x45df5c75, 0xdcd60dcf, 0xabd13d59, 0x26d930ac, 0x51de003a,
    0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423, 0xcfba9599,
    0xb8bda50f, 0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
    0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d, 0x76dc4190,
    0x01db7106, 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f,
    0x9fbfe4a5, 0xe8b8d433, 0x7807c9a2, 0x0f00f934, 0x9609a88e,
    0xe10e9818, 0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
    0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e, 0x6c0695ed,
    0x1b01a57b, 0x8208f4c1, 0xf50fc457, 0x65b0d9c6, 0x12b7e950,
    0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3,
    0xfbd44c65, 0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2,
    0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb, 0x4369e96a,
    0x346ed9fc, 0xad678846, 0xda60b8d0, 0x44042d73, 0x33031de5,
    0xaa0a4c5f, 0xdd0d7cc9, 0x5005713c, 0x270241aa, 0xbe0b1010,
    0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
    0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17,
    0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad, 0xedb88320, 0x9abfb3b6,
    0x03b6e20c, 0x74b1d29a, 0xead54739, 0x9dd277af, 0x04db2615,
    0x73dc1683, 0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8,
    0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1, 0xf00f9344,
    0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb,
    0x196c3671, 0x6e6b06e7, 0xfed41b76, 0x89d32be0, 0x10da7a5a,
    0x67dd4acc, 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
    0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1,
    0xa6bc5767, 0x3fb506dd, 0x48b2364b, 0xd80d2bda, 0xaf0a1b4c,
    0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55, 0x316e8eef,
    0x4669be79, 0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
    0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f, 0xc5ba3bbe,
    0xb2bd0b28, 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31,
    0x2cd99e8b, 0x5bdeae1d, 0x9b64c2b0, 0xec63f226, 0x756aa39c,
    0x026d930a, 0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
    0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38, 0x92d28e9b,
    0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21, 0x86d3d2d4, 0xf1d4e242,
    0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1,
    0x18b74777, 0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c,
    0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45, 0xa00ae278,
    0xd70dd2ee, 0x4e048354, 0x3903b3c2, 0xa7672661, 0xd06016f7,
    0x4969474d, 0x3e6e77db, 0xaed16a4a, 0xd9d65adc, 0x40df0b66,
    0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
    0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605,
    0xcdd70693, 0x54de5729, 0x23d967bf, 0xb3667a2e, 0xc4614ab8,
    0x5d681b02, 0x2a6f2b94, 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b,
    0x2d02ef8d
]
crc_32_tab = map(r_uint, crc_32_tab)

def crc32(s, crc=r_uint(0)):
    crc = ~crc & r_uint(0xffffffffL)
    for c in s:
        crc = crc_32_tab[(crc ^ r_uint(ord(c))) & 0xffL] ^ (crc >> 8)
        #/* Note:  (crc >> 8) MUST zero fill on left
    return crc ^ r_uint(0xffffffffL)

# parts copied from zipfile library implementation

class BadZipfile(Exception):
    pass

# Here are some struct module formats for reading headers
structEndArchive = "<4s4H2lH"     # 9 items, end of archive, 22 bytes
stringEndArchive = "PK\005\006"   # magic number for end of archive record
structCentralDir = "<4s4B4HlLL5HLl"# 19 items, central directory, 46 bytes
stringCentralDir = "PK\001\002"   # magic number for central directory
structFileHeader = "<4s2B4HlLL2H"  # 12 items, file header record, 30 bytes
stringFileHeader = "PK\003\004"   # magic number for file header

# indexes of entries in the central directory structure
_CD_SIGNATURE = 0
_CD_CREATE_VERSION = 1
_CD_CREATE_SYSTEM = 2
_CD_EXTRACT_VERSION = 3
_CD_EXTRACT_SYSTEM = 4                  # is this meaningful?
_CD_FLAG_BITS = 5
_CD_COMPRESS_TYPE = 6
_CD_TIME = 7
_CD_DATE = 8
_CD_CRC = 9
_CD_COMPRESSED_SIZE = 10
_CD_UNCOMPRESSED_SIZE = 11
_CD_FILENAME_LENGTH = 12
_CD_EXTRA_FIELD_LENGTH = 13
_CD_COMMENT_LENGTH = 14
_CD_DISK_NUMBER_START = 15
_CD_INTERNAL_FILE_ATTRIBUTES = 16
_CD_EXTERNAL_FILE_ATTRIBUTES = 17
_CD_LOCAL_HEADER_OFFSET = 18

# indexes of entries in the local file header structure
_FH_SIGNATURE = 0
_FH_EXTRACT_VERSION = 1
_FH_EXTRACT_SYSTEM = 2                  # is this meaningful?
_FH_GENERAL_PURPOSE_FLAG_BITS = 3
_FH_COMPRESSION_METHOD = 4
_FH_LAST_MOD_TIME = 5
_FH_LAST_MOD_DATE = 6
_FH_CRC = 7
_FH_COMPRESSED_SIZE = 8
_FH_UNCOMPRESSED_SIZE = 9
_FH_FILENAME_LENGTH = 10
_FH_EXTRA_FIELD_LENGTH = 11

class EndRecStruct(object):
    def __init__(self, stuff, comment, filesize):
        self.stuff = stuff
        self.comment = comment
        self.filesize = filesize

def _EndRecData(fpin):
    """Return data from the "End of Central Directory" record, or None.

    The data is a list of the nine items in the ZIP "End of central dir"
    record followed by a tenth item, the file seek offset of this record."""
    fpin.seek(-22, 2)               # Assume no archive comment.
    filesize = fpin.tell() + 22     # Get file size
    data = fpin.readall()
    start = len(data)-2
    if start <= 0:
        return    # Error, return None
    if data[0:4] == stringEndArchive and data[start:] == "\000\000":
        endrec = runpack(structEndArchive, data)
        return EndRecStruct(endrec, "", filesize - 22)
    # Search the last END_BLOCK bytes of the file for the record signature.
    # The comment is appended to the ZIP file and has a 16 bit length.
    # So the comment may be up to 64K long.  We limit the search for the
    # signature to a few Kbytes at the end of the file for efficiency.
    # also, the signature must not appear in the comment.
    END_BLOCK = min(filesize, 1024 * 4)
    fpin.seek(filesize - END_BLOCK, 0)
    data = fpin.readall()
    start = data.rfind(stringEndArchive)
    if start >= 0:     # Correct signature string was found
        endrec = runpack(structEndArchive, data[start:start+22])
        comment = data[start+22:]
        if endrec[7] == len(comment):     # Comment length checks out
            # Append the archive comment and start offset
            return EndRecStruct(endrec, comment, filesize - END_BLOCK + start)
    return      # Error, return None

class RZipInfo(object):
    def __init__(self, filename, date_time=(1980,1,1,0,0,0)):
        self.orig_filename = filename
        null_byte = filename.find(chr(0))
        if null_byte >= 0:
            filename = filename[0:null_byte]
# This is used to ensure paths in generated ZIP files always use
# forward slashes as the directory separator, as required by the
# ZIP format specification.
        if os.sep != "/":
            filename = filename.replace(os.sep, "/")
        self.filename = filename        # Normalized file name
        self.date_time = date_time      # year, month, day, hour, min, sec
        # Standard values:
        self.compress_type = ZIP_STORED # Type of compression for the file
        self.comment = ""               # Comment for each file
        self.extra = ""                 # ZIP extra data
        self.create_system = 0          # System which created ZIP archive
        self.create_version = 20        # Version which created ZIP archive
        self.extract_version = 20       # Version needed to extract archive
        self.reserved = 0               # Must be zero
        self.flag_bits = 0              # ZIP flag bits
        self.volume = 0                 # Volume number of file header
        self.internal_attr = 0          # Internal attributes
        self.external_attr = 0          # External file attributes
        # Other attributes are set by class ZipFile:
        # header_offset         Byte offset to the file header
        # file_offset           Byte offset to the start of the file data
        # CRC                   CRC-32 of the uncompressed file
        # compress_size         Size of the compressed file
        # file_size             Size of the uncompressed file

class RZipFile(object):
    def __init__(self, zipname, mode='r', compression=ZIP_STORED):
        if mode != 'r':
            raise TypeError("Read only support by now")
        self.compression = compression
        self.filename = zipname
        self.filelist = []
        self.NameToInfo = {}
        if 'b' not in mode:
            mode += 'b'
        self.mode = mode
        fp = self.get_fp()
        try:
            self._GetContents(fp)
        finally:
            fp.close()

    def get_fp(self):
        return open_file_as_stream(self.filename, self.mode, 1024)

    def _GetContents(self, fp):
        endrec = _EndRecData(fp)
        if not endrec:
            raise BadZipfile("File is not a zip file")
        size_cd = endrec.stuff[5]             # bytes in central directory
        offset_cd = endrec.stuff[6]   # offset of central directory
        self.comment = endrec.comment
        x = endrec.filesize - size_cd
        concat = x - offset_cd
        self.start_dir = offset_cd + concat
        fp.seek(self.start_dir, 0)
        total = 0
        while total < size_cd:
            centdir = fp.read(46)
            total = total + 46
            if centdir[0:4] != stringCentralDir:
                raise BadZipfile("Bad magic number for central directory")
            centdir = runpack(structCentralDir, centdir)
            filename = fp.read(centdir[_CD_FILENAME_LENGTH])
            # Create ZipInfo instance to store file information
            x = RZipInfo(filename)
            x.extra = fp.read(centdir[_CD_EXTRA_FIELD_LENGTH])
            x.comment = fp.read(centdir[_CD_COMMENT_LENGTH])
            total = (total + centdir[_CD_FILENAME_LENGTH]
                     + centdir[_CD_EXTRA_FIELD_LENGTH]
                     + centdir[_CD_COMMENT_LENGTH])
            x.header_offset = centdir[_CD_LOCAL_HEADER_OFFSET] + concat
            # file_offset must be computed below...
            (x.create_version, x.create_system, x.extract_version, x.reserved,
                x.flag_bits, x.compress_type, t, d,
                crc, x.compress_size, x.file_size) = centdir[1:12]
            x.CRC = r_uint(crc) & r_uint(0xffffffff)
            x.dostime = t
            x.dosdate = d
            x.volume, x.internal_attr, x.external_attr = centdir[15:18]
            # Convert date/time code to (year, month, day, hour, min, sec)
            x.date_time = ( (d>>9)+1980, (d>>5)&0xF, d&0x1F,
                                     t>>11, (t>>5)&0x3F, (t&0x1F) * 2 )
            self.filelist.append(x)
            self.NameToInfo[x.filename] = x
        for data in self.filelist:
            fp.seek(data.header_offset, 0)
            fheader = fp.read(30)
            if fheader[0:4] != stringFileHeader:
                raise BadZipfile("Bad magic number for file header")
            fheader = runpack(structFileHeader, fheader)
            # file_offset is computed here, since the extra field for
            # the central directory and for the local file header
            # refer to different fields, and they can have different
            # lengths
            data.file_offset = (data.header_offset + 30
                                + fheader[_FH_FILENAME_LENGTH]
                                + fheader[_FH_EXTRA_FIELD_LENGTH])
            fname = fp.read(fheader[_FH_FILENAME_LENGTH])
            if fname != data.orig_filename:
                raise BadZipfile('File name in directory "%s" and '
                    'header "%s" differ.' % (data.orig_filename, fname))
        fp.seek(self.start_dir, 0)

    def getinfo(self, filename):
        """Return the instance of ZipInfo given 'filename'."""
        return self.NameToInfo[filename]

    def read(self, filename):
        zinfo = self.getinfo(filename)
        fp = self.get_fp()
        try:
            filepos = fp.tell()
            fp.seek(zinfo.file_offset, 0)
            bytes = fp.read(intmask(zinfo.compress_size))
            fp.seek(filepos, 0)
            if zinfo.compress_type == ZIP_STORED:
                pass
            elif zinfo.compress_type == ZIP_DEFLATED and rzlib is not None:
                stream = rzlib.inflateInit(wbits=-15)
                try:
                    bytes, _, _ = rzlib.decompress(stream, bytes)
                    # need to feed in unused pad byte so that zlib won't choke
                    ex, _, _ = rzlib.decompress(stream, 'Z')
                    if ex:
                        bytes = bytes + ex
                finally:
                    rzlib.inflateEnd(stream)
            elif zinfo.compress_type == ZIP_DEFLATED:
                raise BadZipfile("Cannot decompress file, zlib not installed")
            else:
                raise BadZipfile("Unsupported compression method %d for "
                                 "file %s" % (zinfo.compress_type, filename))
            crc = crc32(bytes)
            if crc != zinfo.CRC:
                raise BadZipfile("Bad CRC-32 for file %s" % filename)
            return bytes
        finally:
            fp.close()
