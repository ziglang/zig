import sys
from threading import Lock
from _pypy_openssl import ffi, lib
from _cffi_ssl._stdssl.utility import (_str_to_ffi_buffer, _bytes_with_len,
        _str_from_buf)

try: from __pypy__ import builtinify
except ImportError: builtinify = lambda f: f


def new(name, string=b'', usedforsecurity=True):
    h = HASH(name, usedforsecurity=usedforsecurity)
    h.update(string)
    return h


class HASH(object):

    def __init__(self, name=None, copy_from=None, usedforsecurity=True):
        self.ctx = ffi.NULL
        if name is None:
            raise TypeError("cannot create '%s' instance" % type(self).__name__)
        self.name = str(name).lower()
        digest_type = self.digest_type_by_name()
        self.digest_size = lib.EVP_MD_size(digest_type)

        # Allocate a lock for each HASH object.
        # An optimization would be to not release the GIL on small requests,
        # and use a custom lock only when needed.
        self.lock = Lock()

        # Start EVPnew
        ctx = lib.Cryptography_EVP_MD_CTX_new()
        if ctx == ffi.NULL:
            raise MemoryError
        ctx = ffi.gc(ctx, lib.Cryptography_EVP_MD_CTX_free)


        try:
            if copy_from is not None:
                # cpython uses EVP_MD_CTX_copy(...) and calls this from EVP_copy
                if not lib.EVP_MD_CTX_copy_ex(ctx, copy_from):
                    raise ValueError
            else:
                # cpython uses EVP_DigestInit
                lib.EVP_DigestInit_ex(ctx, digest_type, ffi.NULL)
            self.ctx = ctx
        except:
            # no need to gc ctx! 
            raise
        if not usedforsecurity and lib.EVP_MD_CTX_FLAG_NON_FIPS_ALLOW:
            lib.EVP_MD_CTX_set_flags(ctx, lib.EVP_MD_CTX_FLAG_NON_FIPS_ALLOW)
        # End EVPnew

    def digest_type_by_name(self):
        c_name = _str_to_ffi_buffer(self.name)
        digest_type = lib.EVP_get_digestbyname(c_name)
        if not digest_type:
            raise ValueError("unknown hash function")
        # TODO
        return digest_type

    def __repr__(self):
        return "<%s HASH object at 0x%s>" % (self.name, id(self))

    def update(self, string):
        if isinstance(string, str):
            raise TypeError("Unicode-objects must be encoded before hashing")
        elif isinstance(string, memoryview):
            # issue 2756: ffi.from_buffer() cannot handle memoryviews
            string = string.tobytes()
        buf = ffi.from_buffer(string)
        with self.lock:
            # XXX try to not release the GIL for small requests
            lib.EVP_DigestUpdate(self.ctx, buf, len(buf))

    def copy(self):
        """Return a copy of the hash object."""
        with self.lock:
            return HASH(self.name, copy_from=self.ctx)

    def digest(self):
        """Return the digest value as a string of binary data."""
        return self._digest()

    def hexdigest(self):
        """Return the digest value as a string of hexadecimal digits."""
        digest = self._digest()
        hexdigits = '0123456789abcdef'
        result = []
        for c in digest:
            result.append(hexdigits[(c >> 4) & 0xf])
            result.append(hexdigits[ c       & 0xf])
        return ''.join(result)

    @property
    def block_size(self):
        return lib.EVP_MD_CTX_block_size(self.ctx)

    def _digest(self):
        ctx = lib.Cryptography_EVP_MD_CTX_new()
        if ctx == ffi.NULL:
            raise MemoryError
        try:
            with self.lock:
                if not lib.EVP_MD_CTX_copy_ex(ctx, self.ctx):
                    raise ValueError
            digest_size = self.digest_size
            buf = ffi.new("unsigned char[]", digest_size)
            lib.EVP_DigestFinal_ex(ctx, buf, ffi.NULL)
            return _bytes_with_len(buf, digest_size)
        finally:
            lib.Cryptography_EVP_MD_CTX_free(ctx)

class HASHXOF(HASH):
    pass

algorithms = ('md5', 'sha1', 'sha224', 'sha256', 'sha384', 'sha512')

class NameFetcher:
    def __init__(self):
        self.meth_names = []
        self.error = None


def _fetch_names():
    name_fetcher = NameFetcher()
    handle = ffi.new_handle(name_fetcher)
    lib.OBJ_NAME_do_all(lib.OBJ_NAME_TYPE_MD_METH, hash_name_mapper_callback, handle)
    if name_fetcher.error:
        raise name_fetcher.error
    meth_names = name_fetcher.meth_names
    name_fetcher.meth_names = None
    return frozenset(meth_names)

@ffi.callback("void(OBJ_NAME*, void*)")
def hash_name_mapper_callback(obj_name, userdata):
    if not obj_name:
        return
    # Ignore aliased names, they pollute the list and OpenSSL appears
    # to have a its own definition of alias as the resulting list
    # still contains duplicate and alternate names for several
    # algorithms.
    if obj_name.alias != 0:
        return
    name = _str_from_buf(obj_name.name)
    if name in ('blake2b512', 'sha3-512'):
        return
    name_fetcher = ffi.from_handle(userdata)
    name_fetcher.meth_names.append(name)

openssl_md_meth_names = _fetch_names()
del _fetch_names

# shortcut functions
def make_new_hash(name, funcname):
    def new_hash(string=b'', usedforsecurity=True):
        return new(name, string, usedforsecurity=True)
    new_hash.__name__ = funcname
    return builtinify(new_hash)

for _name in algorithms:
    _newname = 'openssl_%s' % (_name,)
    globals()[_newname] = make_new_hash(_name, _newname)

if hasattr(lib, 'PKCS5_PBKDF2_HMAC'):
    @builtinify
    def pbkdf2_hmac(hash_name, password, salt, iterations, dklen=None):
        if not isinstance(hash_name, str):
            raise TypeError("expected 'str' for name, but got %s" % type(hash_name))
        c_name = _str_to_ffi_buffer(hash_name)
        digest = lib.EVP_get_digestbyname(c_name)
        if digest == ffi.NULL:
            raise ValueError("unsupported hash type")
        if dklen is None:
            dklen = lib.EVP_MD_size(digest)
        if dklen < 1:
            raise ValueError("key length must be greater than 0.")
        if dklen >= sys.maxsize:
            raise OverflowError("key length is too great.")
        if iterations < 1:
            raise ValueError("iteration value must be greater than 0.")
        if iterations >= sys.maxsize:
            raise OverflowError("iteration value is too great.")
        key = ffi.new("unsigned char[]", dklen)
        c_password = ffi.from_buffer(bytes(password))
        c_salt = ffi.from_buffer(bytes(salt))
        r = lib.PKCS5_PBKDF2_HMAC(c_password, len(c_password),
                ffi.cast("unsigned char*",c_salt), len(c_salt),
                iterations, digest, dklen, key)
        if r == 0:
            raise ValueError
        return _bytes_with_len(key, dklen)
