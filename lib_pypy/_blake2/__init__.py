import codecs

def make_blake_hash(class_name, cffi_mod):
    _ffi = cffi_mod.ffi
    _lib = cffi_mod.lib

    class _blake:
        SALT_SIZE = _lib.BLAKE_SALTBYTES
        PERSON_SIZE = _lib.BLAKE_PERSONALBYTES
        MAX_KEY_SIZE = _lib.BLAKE_KEYBYTES
        MAX_DIGEST_SIZE = _lib.BLAKE_OUTBYTES

        def __new__(cls, _string=None, *, digest_size=MAX_DIGEST_SIZE,
                    key=None, salt=None, person=None, fanout=1, depth=1,
                    leaf_size=None, node_offset=None, node_depth=0,
                    inner_size=0, last_node=False, usedforsecurity=True):
            self = super().__new__(cls)

            self._param = _ffi.new("blake_param*")
            self._state = _ffi.new("blake_state*")

            # Set digest size.
            if not 1 <= digest_size <= self.MAX_DIGEST_SIZE:
                raise ValueError(
                    "digest_size must be between 1 and %s bytes" %
                    self.MAX_DIGEST_SIZE)
            self._param.digest_length = digest_size

            # Set salt parameter.
            if salt is not None:
                if len(salt) > self.SALT_SIZE:
                    raise ValueError(
                        "maximum salt length is %d bytes" %
                        self.SALT_SIZE)
                _ffi.memmove(self._param.salt, salt, len(salt))

            # Set personalization parameter.
            if person:
                if len(person) > _lib.BLAKE_PERSONALBYTES:
                    raise ValueError("maximum person length is %d bytes" %
                                     _lib.BLAKE_PERSONALBYTES)
                _ffi.memmove(self._param.personal, person, len(person))

            # Set tree parameters.
            if not 0 <= fanout <= 255:
                raise ValueError("fanout must be between 0 and 255")
            self._param.fanout = fanout

            if not 1 <= depth <= 255:
                raise ValueError("depth must be between 1 and 255")
            self._param.depth = depth

            if leaf_size is not None:
                if leaf_size > 0xFFFFFFFF:
                    raise OverflowError("leaf_size is too large")
                if leaf_size < 0:
                    raise ValueError("value must be positive")
                # NB: Simple assignment here would be incorrect on big
                # endian platforms.
                _lib.store32(_ffi.addressof(self._param, 'leaf_length'),
                             leaf_size)

            if node_offset is not None:
                if node_offset < 0:
                    raise ValueError("value must be positive")
                if class_name == 'blake2s':
                    if node_offset > 0xFFFFFFFFFFFF:
                        # maximum 2**48 - 1
                        raise OverflowError("node_offset is too large")
                    _lib.store48(_lib.addressof_node_offset(self._param),
                                 node_offset)
                else:
                    # NB: Simple assignment here would be incorrect on big
                    # endian platforms.
                    _lib.store64(_lib.addressof_node_offset(self._param),
                                 node_offset)

            if not 0 <= node_depth <= 255:
                raise ValueError("node_depth must be between 0 and 255")
            self._param.node_depth = node_depth

            if not 0 <= inner_size <= _lib.BLAKE_OUTBYTES:
                raise ValueError("inner_size must be between 0 and is %d" %
                                 _lib.BLAKE_OUTBYTES)
            self._param.inner_length = inner_size

            # Set key length.
            if key:
                if len(key) > _lib.BLAKE_KEYBYTES:
                    raise ValueError("maximum key length is %d bytes" %
                                     _lib.BLAKE_KEYBYTES)
                self._param.key_length = len(key)

            # Initialize hash state.
            if _lib.blake_init_param(self._state, self._param) < 0:
                raise RuntimeError("error initializing hash state")

            # Set last node flag (must come after initialization).
            self._state.last_node = last_node

            # Process key block if any.
            if key:
                block = _ffi.new("uint8_t[]", _lib.BLAKE_BLOCKBYTES)
                _ffi.memmove(block, key, len(key))
                _lib.blake_update(self._state, block, len(block))
                # secure_zero_memory(block, sizeof(block)

            if _string is not None:
                self.update(_string)
            return self

        @property
        def name(self):
            return class_name

        @property
        def block_size(self):
            return _lib.BLAKE_BLOCKBYTES

        @property
        def digest_size(self):
            return self._param.digest_length

        def update(self, data):
            data = _ffi.from_buffer(data)
            _lib.blake_update(self._state, data, len(data))

        def digest(self):
            digest = _ffi.new("char[]", _lib.BLAKE_OUTBYTES)
            state_copy = _ffi.new("blake_state*")
            _ffi.memmove(state_copy, self._state, _ffi.sizeof("blake_state"))
            _lib.blake_final(state_copy, digest, self._param.digest_length)
            return _ffi.unpack(digest, self._param.digest_length)

        def hexdigest(self):
            return codecs.encode(self.digest(), 'hex').decode()

        def copy(self):
            copy = super().__new__(type(self))
            copy._state = _ffi.new("blake_state*")
            _ffi.memmove(copy._state, self._state, _ffi.sizeof("blake_state"))
            copy._param = _ffi.new("blake_param*")
            _ffi.memmove(copy._param, self._param, _ffi.sizeof("blake_param"))
            return copy

    _blake.__name__ = class_name
    _blake.__qualname__ = class_name
    return _blake


from . import _blake2b_cffi
blake2b = make_blake_hash('blake2b', _blake2b_cffi)

from . import _blake2s_cffi
blake2s = make_blake_hash('blake2s', _blake2s_cffi)
