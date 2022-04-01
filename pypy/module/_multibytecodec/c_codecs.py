import py
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator import cdir
from rpython.rlib import rutf8

UNICODE_REPLACEMENT_CHARACTER = u'\uFFFD'.encode("utf8")


class EncodeDecodeError(Exception):
    def __init__(self, start, end, reason):
        self.start = start
        self.end = end
        self.reason = reason
    def __repr__(self):
        return 'EncodeDecodeError(%r, %r, %r)' % (self.start, self.end,
                                                  self.reason)

srcdir = py.path.local(__file__).dirpath()

codecs = [
    # _codecs_cn
    'gb2312', 'gbk', 'gb18030', 'hz',

    # _codecs_hk
    'big5hkscs',

    # _codecs_iso2022
    'iso2022_kr', 'iso2022_jp', 'iso2022_jp_1', 'iso2022_jp_2',
    'iso2022_jp_2004', 'iso2022_jp_3', 'iso2022_jp_ext',

    # _codecs_jp
    'shift_jis', 'cp932', 'euc_jp', 'shift_jis_2004',
    'euc_jis_2004', 'euc_jisx0213', 'shift_jisx0213',

    # _codecs_kr
    'euc_kr', 'cp949', 'johab',

    # _codecs_tw
    'big5', 'cp950',
]

eci = ExternalCompilationInfo(
    separate_module_files = [
        srcdir.join('src', 'cjkcodecs', '_codecs_cn.c'),
        srcdir.join('src', 'cjkcodecs', '_codecs_hk.c'),
        srcdir.join('src', 'cjkcodecs', '_codecs_iso2022.c'),
        srcdir.join('src', 'cjkcodecs', '_codecs_jp.c'),
        srcdir.join('src', 'cjkcodecs', '_codecs_kr.c'),
        srcdir.join('src', 'cjkcodecs', '_codecs_tw.c'),
        srcdir.join('src', 'cjkcodecs', 'multibytecodec.c'),
    ],
    includes = ['src/cjkcodecs/multibytecodec.h'],
    include_dirs = [str(srcdir), cdir],
)

MBERR_TOOSMALL = -1  # insufficient output buffer space
MBERR_TOOFEW   = -2  # incomplete input buffer
MBERR_INTERNAL = -3  # internal runtime error
MBERR_NOMEMORY = -4  # out of memory

MULTIBYTECODEC_P = rffi.COpaquePtr('struct MultibyteCodec_s',
                                   compilation_info=eci)

def llexternal(*args, **kwds):
    kwds.setdefault('compilation_info', eci)
    kwds.setdefault('sandboxsafe', True)
    kwds.setdefault('_nowrapper', True)
    return rffi.llexternal(*args, **kwds)

def getter_for(name):
    return llexternal('pypy_cjkcodec_%s' % name, [], MULTIBYTECODEC_P)

_codecs_getters = dict([(name, getter_for(name)) for name in codecs])
assert len(_codecs_getters) == len(codecs)

def getcodec(name):
    getter = _codecs_getters[name]
    return getter()

# ____________________________________________________________
# Decoding

DECODEBUF_P = rffi.COpaquePtr('struct pypy_cjk_dec_s', compilation_info=eci)
pypy_cjk_dec_new = llexternal('pypy_cjk_dec_new',
                              [MULTIBYTECODEC_P], DECODEBUF_P)
pypy_cjk_dec_init = llexternal('pypy_cjk_dec_init',
                               [DECODEBUF_P, rffi.CCHARP, rffi.SSIZE_T],
                               rffi.SSIZE_T)
pypy_cjk_dec_free = llexternal('pypy_cjk_dec_free', [DECODEBUF_P],
                               lltype.Void)
pypy_cjk_dec_chunk = llexternal('pypy_cjk_dec_chunk', [DECODEBUF_P],
                                rffi.SSIZE_T)
pypy_cjk_dec_outbuf = llexternal('pypy_cjk_dec_outbuf', [DECODEBUF_P],
                                 rffi.CWCHARP)
pypy_cjk_dec_outlen = llexternal('pypy_cjk_dec_outlen', [DECODEBUF_P],
                                 rffi.SSIZE_T)
pypy_cjk_dec_inbuf_remaining = llexternal('pypy_cjk_dec_inbuf_remaining',
                                          [DECODEBUF_P], rffi.SSIZE_T)
pypy_cjk_dec_inbuf_consumed = llexternal('pypy_cjk_dec_inbuf_consumed',
                                         [DECODEBUF_P], rffi.SSIZE_T)
pypy_cjk_dec_replace_on_error = llexternal('pypy_cjk_dec_replace_on_error',
                                           [DECODEBUF_P, rffi.CWCHARP,
                                            rffi.SSIZE_T, rffi.SSIZE_T],
                                           rffi.SSIZE_T)

def decode(codec, stringdata, errors="strict", errorcb=None, namecb=None):
    decodebuf = pypy_cjk_dec_new(codec)
    if not decodebuf:
        raise MemoryError
    try:
        return decodeex(decodebuf, stringdata, errors, errorcb, namecb)
    finally:
        pypy_cjk_dec_free(decodebuf)

def decodeex(decodebuf, stringdata, errors="strict", errorcb=None, namecb=None,
             ignore_error=0):
    inleft = len(stringdata)
    with rffi.scoped_nonmovingbuffer(stringdata) as inbuf:
        if pypy_cjk_dec_init(decodebuf, inbuf, inleft) < 0:
            raise MemoryError
        while True:
            r = pypy_cjk_dec_chunk(decodebuf)
            if r == 0 or r == ignore_error:
                break
            multibytecodec_decerror(decodebuf, r, errors,
                                    errorcb, namecb, stringdata)
        src = pypy_cjk_dec_outbuf(decodebuf)
        length = pypy_cjk_dec_outlen(decodebuf)
        return rffi.wcharpsize2utf8(src, length) # assumes no out-of-range chars

def multibytecodec_decerror(decodebuf, e, errors,
                            errorcb, namecb, stringdata):
    if e > 0:
        reason = "illegal multibyte sequence"
        esize = e
    elif e == MBERR_TOOFEW:
        reason = "incomplete multibyte sequence"
        esize = pypy_cjk_dec_inbuf_remaining(decodebuf)
    elif e == MBERR_NOMEMORY:
        raise MemoryError
    else:
        raise RuntimeError
    #
    # compute the unicode to use as a replacement -> 'replace', and
    # the current position in the input 'unicodedata' -> 'end'
    start = pypy_cjk_dec_inbuf_consumed(decodebuf)
    end = start + esize
    if errors == "strict":
        raise EncodeDecodeError(start, end, reason)
    elif errors == "ignore":
        replace = ""
    elif errors == "replace":
        replace = UNICODE_REPLACEMENT_CHARACTER
    else:
        assert errorcb
        replace, end, rettype, obj = errorcb(errors, namecb, reason,
                               stringdata, start, end)
        # 'replace' is UTF8 encoded unicode, rettype is 'u'
    lgt = rutf8.codepoints_in_utf8(replace)
    inbuf = rffi.utf82wcharp(replace, lgt)
    try:
        r = pypy_cjk_dec_replace_on_error(decodebuf, inbuf, lgt, end)
    finally:
        lltype.free(inbuf, flavor='raw')
    if r == MBERR_NOMEMORY:
        raise MemoryError

# ____________________________________________________________
# Encoding
ENCODEBUF_P = rffi.COpaquePtr('struct pypy_cjk_enc_s', compilation_info=eci)
pypy_cjk_enc_new = llexternal('pypy_cjk_enc_new',
                               [MULTIBYTECODEC_P], ENCODEBUF_P)
pypy_cjk_enc_init = llexternal('pypy_cjk_enc_init',
                               [ENCODEBUF_P, rffi.CWCHARP, rffi.SSIZE_T],
                               rffi.SSIZE_T)
pypy_cjk_enc_free = llexternal('pypy_cjk_enc_free', [ENCODEBUF_P],
                               lltype.Void)
pypy_cjk_enc_chunk = llexternal('pypy_cjk_enc_chunk',
                                [ENCODEBUF_P, rffi.SSIZE_T], rffi.SSIZE_T)
pypy_cjk_enc_reset = llexternal('pypy_cjk_enc_reset', [ENCODEBUF_P],
                                rffi.SSIZE_T)
pypy_cjk_enc_outbuf = llexternal('pypy_cjk_enc_outbuf', [ENCODEBUF_P],
                                 rffi.CCHARP)
pypy_cjk_enc_outlen = llexternal('pypy_cjk_enc_outlen', [ENCODEBUF_P],
                                 rffi.SSIZE_T)
pypy_cjk_enc_inbuf_remaining = llexternal('pypy_cjk_enc_inbuf_remaining',
                                          [ENCODEBUF_P], rffi.SSIZE_T)
pypy_cjk_enc_inbuf_consumed = llexternal('pypy_cjk_enc_inbuf_consumed',
                                         [ENCODEBUF_P], rffi.SSIZE_T)
pypy_cjk_enc_replace_on_error = llexternal('pypy_cjk_enc_replace_on_error',
                                           [ENCODEBUF_P, rffi.CCHARP,
                                            rffi.SSIZE_T, rffi.SSIZE_T],
                                           rffi.SSIZE_T)
pypy_cjk_enc_getcodec = llexternal('pypy_cjk_enc_getcodec',
                                   [ENCODEBUF_P], MULTIBYTECODEC_P)
pypy_cjk_enc_copystate = llexternal('pypy_cjk_enc_copystate',
                                    [ENCODEBUF_P, ENCODEBUF_P], lltype.Void)
MBENC_FLUSH = 1
MBENC_RESET = 2

def encode(codec, unicodedata, length, errors="strict", errorcb=None,
           namecb=None, copystate=lltype.nullptr(ENCODEBUF_P.TO)):
    encodebuf = pypy_cjk_enc_new(codec)
    if not encodebuf:
        raise MemoryError
    if copystate:
        pypy_cjk_enc_copystate(encodebuf, copystate)
    try:
        return encodeex(encodebuf, unicodedata, length, errors, errorcb, namecb)
    finally:
        if copystate:
            pypy_cjk_enc_copystate(copystate, encodebuf)
        pypy_cjk_enc_free(encodebuf)

def encodeex(encodebuf, utf8data, length, errors="strict", errorcb=None,
             namecb=None, ignore_error=0):
    inleft = length
    inbuf = rffi.utf82wcharp(utf8data, length)
    try:
        if pypy_cjk_enc_init(encodebuf, inbuf, inleft) < 0:
            raise MemoryError
        if ignore_error == 0:
            flags = MBENC_FLUSH | MBENC_RESET
        else:
            flags = 0
        while True:
            r = pypy_cjk_enc_chunk(encodebuf, flags)
            if r == 0 or r == ignore_error:
                break
            multibytecodec_encerror(encodebuf, r, errors,
                                    errorcb, namecb, utf8data)
        while flags & MBENC_RESET:
            r = pypy_cjk_enc_reset(encodebuf)
            if r == 0:
                break
            multibytecodec_encerror(encodebuf, r, errors,
                                    errorcb, namecb, utf8data)
        src = pypy_cjk_enc_outbuf(encodebuf)
        length = pypy_cjk_enc_outlen(encodebuf)
        return rffi.charpsize2str(src, length)
    finally:
        lltype.free(inbuf, flavor='raw')

def multibytecodec_encerror(encodebuf, e, errors,
                            errorcb, namecb, unicodedata):
    if e > 0:
        reason = "illegal multibyte sequence"
        esize = e
    elif e == MBERR_TOOFEW:
        reason = "incomplete multibyte sequence"
        esize = pypy_cjk_enc_inbuf_remaining(encodebuf)
    elif e == MBERR_NOMEMORY:
        raise MemoryError
    else:
        raise RuntimeError
    #
    # compute the string to use as a replacement -> 'replace', and
    # the current position in the input 'unicodedata' -> 'end'
    start = pypy_cjk_enc_inbuf_consumed(encodebuf)
    end = start + esize
    if errors == "strict":
        raise EncodeDecodeError(start, end, reason)
    elif errors == "ignore":
        replace = ""
        rettype = 'b'   # != 'u'
    elif errors == "replace":
        replace = "?"    # utf-8 unicode
        rettype = 'u'
    else:
        assert errorcb
        replace, end, rettype, obj = errorcb(errors, namecb, reason,
                            unicodedata, start, end)
    if rettype == 'u':
        codec = pypy_cjk_enc_getcodec(encodebuf)
        lgt = rutf8.check_utf8(replace, False)
        replace = encode(codec, replace, lgt, copystate=encodebuf)
    #else:
    #   replace is meant to be a byte string already
    with rffi.scoped_nonmovingbuffer(replace) as inbuf:
        r = pypy_cjk_enc_replace_on_error(encodebuf, inbuf, len(replace), end)
    if r == MBERR_NOMEMORY:
        raise MemoryError
