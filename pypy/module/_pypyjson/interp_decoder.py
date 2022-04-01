import sys
from rpython.rlib.rstring import StringBuilder
from rpython.rlib.objectmodel import specialize, always_inline
from rpython.rlib import rfloat, runicode, jit, objectmodel, rutf8
from rpython.rtyper.lltypesystem import lltype, rffi
from pypy.interpreter.error import oefmt, OperationError
from rpython.rlib.rarithmetic import r_uint
from pypy.interpreter import unicodehelper
from pypy.interpreter.baseobjspace import W_Root
from pypy.module._pypyjson import simd

OVF_DIGITS = len(str(sys.maxint))

def is_whitespace(ch):
    return ch == ' ' or ch == '\t' or ch == '\r' or ch == '\n'

# precomputing negative powers of 10 is MUCH faster than using e.g. math.pow
# at runtime
NEG_POW_10 = [10.0**-i for i in range(16)]
del i

def neg_pow_10(x, exp):
    if exp >= len(NEG_POW_10):
        return 0.0
    return x * NEG_POW_10[exp]


class IntCache(object):
    """ A cache for wrapped ints between START and END """

    # I also tried various combinations of having an LRU cache for ints as
    # well, didn't really help.

    # XXX one thing to do would be to use withintprebuilt in general again,
    # hidden behind a 'we_are_jitted'

    START = -10
    END = 256

    def __init__(self, space):
        self.space = space
        self.cache = [self.space.newint(i)
                for i in range(self.START, self.END)]

    def newint(self, intval):
        if self.START <= intval < self.END:
            return self.cache[intval - self.START]
        return self.space.newint(intval)

class DecoderError(Exception):
    def __init__(self, msg, pos):
        self.msg = msg
        self.pos = pos

class JSONDecoder(W_Root):

    LRU_SIZE = 16
    LRU_MASK = LRU_SIZE - 1

    DEFAULT_SIZE_SCRATCH = 20

    # string caching is only used if the total size of the message is larger
    # than a megabyte. Below that, there can't be that many repeated big
    # strings anyway (some experiments showed this to be a reasonable cutoff
    # size)
    MIN_SIZE_FOR_STRING_CACHE = 1024 * 1024

    # evaluate the string cache for 200 strings, before looking at the hit rate
    # and deciding whether to keep doing it
    STRING_CACHE_EVALUATION_SIZE = 200

    # keep using the string cache if at least 25% of all decoded strings are a
    # hit in the cache
    STRING_CACHE_USEFULNESS_FACTOR = 4

    # don't make arbitrarily huge maps
    MAX_MAP_SIZE = 100


    def __init__(self, space, s):
        self.space = space
        self.w_empty_string = space.newutf8("", 0)

        self.s = s

        # we put our string in a raw buffer so:
        # 1) we automatically get the '\0' sentinel at the end of the string,
        #    which means that we never have to check for the "end of string"
        # 2) we can pass the buffer directly to strtod
        self.ll_chars, self.llobj, self.flag = rffi.get_nonmovingbuffer_ll_final_null(self.s)
        self.end_ptr = lltype.malloc(rffi.CCHARPP.TO, 1, flavor='raw')
        self.pos = 0
        self.intcache = space.fromcache(IntCache)

        # two caches, one for keys, one for general strings. they both have the
        # form {hash-as-int: StringCacheEntry} and they don't deal with
        # collisions at all. For every hash there is simply one string stored
        # and we ignore collisions.
        self.cache_keys = {}
        self.cache_values = {}

        # we don't cache *all* non-key strings, that would be too expensive.
        # instead, keep a cache of the last 16 strings hashes around and add a
        # string to the cache only if its hash is seen a second time
        self.lru_cache = [0] * self.LRU_SIZE
        self.lru_index = 0

        self.startmap = self.space.fromcache(Terminator)

        # keep a list of objects that are created with maps that aren't clearly
        # useful. If they turn out to be useful in the end we are good,
        # otherwise convert them to dicts (see .close())
        self.unclear_objects = []

        # this is a freelist of lists that store the decoded value of an
        # object, before they get copied into the eventual dict
        self.scratch = [[None] * self.DEFAULT_SIZE_SCRATCH]


    def close(self):
        rffi.free_nonmovingbuffer_ll(self.ll_chars, self.llobj, self.flag)
        lltype.free(self.end_ptr, flavor='raw')
        # clean up objects that are instances of now blocked maps
        for w_obj in self.unclear_objects:
            jsonmap = self._get_jsonmap_from_dict(w_obj)
            if jsonmap.is_state_blocked():
                self._devolve_jsonmap_dict(w_obj)

    def getslice(self, start, end):
        assert start >= 0
        assert end >= 0
        return self.s[start:end]

    def skip_whitespace(self, i):
        ll_chars = self.ll_chars
        while True:
            ch = ll_chars[i]
            if is_whitespace(ch):
                i += 1
            else:
                break
        return i

    def decode_any(self, i, contextmap=None):
        """ Decode an object at position i. Optionally pass a contextmap, if
        the value is decoded as the value of a dict. """
        i = self.skip_whitespace(i)
        ch = self.ll_chars[i]
        if ch == '"':
            return self.decode_string(i+1, contextmap)
        elif ch == '[':
            return self.decode_array(i+1)
        elif ch == '{':
            return self.decode_object(i+1)
        elif ch == 'n':
            return self.decode_null(i+1)
        elif ch == 't':
            return self.decode_true(i+1)
        elif ch == 'f':
            return self.decode_false(i+1)
        elif ch == 'I':
            return self.decode_infinity(i+1)
        elif ch == 'N':
            return self.decode_nan(i+1)
        elif ch == '-':
            if self.ll_chars[i+1] == 'I':
                return self.decode_infinity(i+2, sign=-1)
            return self.decode_numeric(i)
        elif ch.isdigit():
            return self.decode_numeric(i)
        else:
            raise DecoderError("Unexpected '%s'" % ch, i)


    def _raise(self, msg, pos):
        raise DecoderError(msg, pos)

    def decode_null(self, i):
        if (self.ll_chars[i]   == 'u' and
            self.ll_chars[i+1] == 'l' and
            self.ll_chars[i+2] == 'l'):
            self.pos = i+3
            return self.space.w_None
        raise DecoderError("Error when decoding null", i)

    def decode_true(self, i):
        if (self.ll_chars[i]   == 'r' and
            self.ll_chars[i+1] == 'u' and
            self.ll_chars[i+2] == 'e'):
            self.pos = i+3
            return self.space.w_True
        raise DecoderError("Error when decoding true", i)

    def decode_false(self, i):
        if (self.ll_chars[i]   == 'a' and
            self.ll_chars[i+1] == 'l' and
            self.ll_chars[i+2] == 's' and
            self.ll_chars[i+3] == 'e'):
            self.pos = i+4
            return self.space.w_False
        raise DecoderError("Error when decoding false", i)

    def decode_infinity(self, i, sign=1):
        if (self.ll_chars[i]   == 'n' and
            self.ll_chars[i+1] == 'f' and
            self.ll_chars[i+2] == 'i' and
            self.ll_chars[i+3] == 'n' and
            self.ll_chars[i+4] == 'i' and
            self.ll_chars[i+5] == 't' and
            self.ll_chars[i+6] == 'y'):
            self.pos = i+7
            return self.space.newfloat(rfloat.INFINITY * sign)
        raise DecoderError("Error when decoding Infinity", i)

    def decode_nan(self, i):
        if (self.ll_chars[i]   == 'a' and
            self.ll_chars[i+1] == 'N'):
            self.pos = i+2
            return self.space.newfloat(rfloat.NAN)
        raise DecoderError("Error when decoding NaN", i)

    def decode_numeric(self, i):
        start = i
        i, ovf_maybe, intval = self.parse_integer(i)
        #
        # check for the optional fractional part
        ch = self.ll_chars[i]
        if ch == '.':
            if not self.ll_chars[i+1].isdigit():
                raise DecoderError("Expected digit", i+1)
            return self.decode_float(start)
        elif ch == 'e' or ch == 'E':
            return self.decode_float(start)
        elif ovf_maybe:
            return self.decode_int_slow(start)

        self.pos = i
        return self.intcache.newint(intval)

    def decode_float(self, i):
        from rpython.rlib import rdtoa
        start = rffi.ptradd(self.ll_chars, i)
        floatval = rdtoa.dg_strtod(rffi.cast(rffi.CONST_CCHARP, start), self.end_ptr)
        diff = rffi.cast(rffi.SIGNED, self.end_ptr[0]) - rffi.cast(rffi.SIGNED, start)
        self.pos = i + diff
        return self.space.newfloat(floatval)

    def decode_int_slow(self, i):
        start = i
        if self.ll_chars[i] == '-':
            i += 1
        while self.ll_chars[i].isdigit():
            i += 1
        s = self.getslice(start, i)
        self.pos = i
        return self.space.call_function(self.space.w_int, self.space.newtext(s))

    @always_inline
    def parse_integer(self, i):
        "Parse a decimal number with an optional minus sign"
        sign = 1
        # parse the sign
        if self.ll_chars[i] == '-':
            sign = -1
            i += 1
        elif self.ll_chars[i] == '+':
            i += 1
        #
        if self.ll_chars[i] == '0':
            i += 1
            return i, False, 0

        intval = 0
        start = i
        while True:
            ch = self.ll_chars[i]
            if ch.isdigit():
                intval = intval*10 + ord(ch)-ord('0')
                i += 1
            else:
                break
        count = i - start
        if count == 0:
            raise DecoderError("Expected digit", i)
        # if the number has more digits than OVF_DIGITS, it might have
        # overflowed
        ovf_maybe = (count >= OVF_DIGITS)
        return i, ovf_maybe, sign * intval

    def _raise_control_char_in_string(self, ch, startindex, currindex):
        if ch == '\0':
            self._raise("Unterminated string starting at",
                        startindex - 1)
        else:
            self._raise("Invalid control character at", currindex-1)

    def _raise_object_error(self, ch, start, i):
        if ch == '\0':
            self._raise("Unterminated object starting at", start)
        else:
            self._raise("Unexpected '%s' when decoding object" % ch, i)

    def decode_array(self, i):
        """ Decode a list. i must be after the opening '[' """
        w_list = self.space.newlist([])
        start = i
        i = self.skip_whitespace(start)
        if self.ll_chars[i] == ']':
            self.pos = i+1
            return w_list
        #
        while True:
            w_item = self.decode_any(i)
            i = self.pos
            self.space.call_method(w_list, 'append', w_item)
            i = self.skip_whitespace(i)
            ch = self.ll_chars[i]
            i += 1
            if ch == ']':
                self.pos = i
                return w_list
            elif ch == ',':
                pass
            elif ch == '\0':
                raise DecoderError("Unterminated array starting at", start)
            else:
                raise DecoderError("Unexpected '%s' when decoding array" % ch,
                                   i-1)

    def decode_object(self, i):
        start = i

        i = self.skip_whitespace(i)
        if self.ll_chars[i] == '}':
            self.pos = i+1
            return self.space.newdict()

        if self.scratch:
            values_w = self.scratch.pop()
        else:
            values_w = [None] * self.DEFAULT_SIZE_SCRATCH
        nextindex = 0
        currmap = self.startmap
        while True:
            # parse a key: value
            newmap = self.decode_key_map(i, currmap)
            if newmap is None:
                # We've seen a repeated value, switch to dict-based storage.
                dict_w = self._switch_to_dict(currmap, values_w, nextindex)
                # We re-parse the last key, to get the correct overwriting
                # effect. Pointless to care for performance here.
                return self.decode_object_dict(i, start, dict_w)
            currmap = newmap
            i = self.skip_whitespace(self.pos)
            ch = self.ll_chars[i]
            if ch != ':':
                raise DecoderError("No ':' found at", i)
            i += 1

            w_value = self.decode_any(i, currmap)

            if nextindex == len(values_w):  # full
                values_w = values_w + [None] * len(values_w)  # double
            values_w[nextindex] = w_value
            nextindex += 1
            i = self.skip_whitespace(self.pos)
            ch = self.ll_chars[i]
            i += 1
            if ch == '}':
                self.pos = i
                self.scratch.append(values_w)  # can reuse next time
                if currmap.is_state_blocked():
                    dict_w = self._switch_to_dict(currmap, values_w, nextindex)
                    return self._create_dict(dict_w)
                values_w = values_w[:nextindex]
                w_res = self._create_dict_map(values_w, currmap)
                if not currmap.is_state_useful():
                    self.unclear_objects.append(w_res)
                return w_res
            elif ch == ',':
                i = self.skip_whitespace(i)
                if currmap.is_state_blocked() or nextindex > self.MAX_MAP_SIZE:
                    self.scratch.append(values_w)  # can reuse next time
                    dict_w = self._switch_to_dict(currmap, values_w, nextindex)
                    return self.decode_object_dict(i, start, dict_w)
            else:
                self._raise_object_error(ch, start, i - 1)

    def _create_dict_map(self, values_w, jsonmap):
        from pypy.objspace.std.jsondict import from_values_and_jsonmap
        return from_values_and_jsonmap(self.space, values_w, jsonmap)

    def _devolve_jsonmap_dict(self, w_dict):
        from pypy.objspace.std.jsondict import devolve_jsonmap_dict
        devolve_jsonmap_dict(w_dict)

    def _get_jsonmap_from_dict(self, w_dict):
        from pypy.objspace.std.jsondict import get_jsonmap_from_dict
        return get_jsonmap_from_dict(w_dict)

    def _switch_to_dict(self, currmap, values_w, nextindex):
        dict_w = self._create_empty_dict()
        currmap.fill_dict(dict_w, values_w)
        assert len(dict_w) == nextindex
        return dict_w

    def decode_object_dict(self, i, start, dict_w):
        while True:
            # parse a key: value
            w_key = self.decode_key_string(i)
            i = self.skip_whitespace(self.pos)
            ch = self.ll_chars[i]
            if ch != ':':
                self._raise("No ':' found at", i)
            i += 1

            w_value = self.decode_any(i)
            dict_w[w_key] = w_value
            i = self.skip_whitespace(self.pos)
            ch = self.ll_chars[i]
            i += 1
            if ch == '}':
                self.pos = i
                return self._create_dict(dict_w)
            elif ch == ',':
                i = self.skip_whitespace(i)
            else:
                self._raise_object_error(ch, start, i - 1)

    def decode_string_uncached(self, i):
        start = i
        ll_chars = self.ll_chars
        nonascii, i = simd.find_end_of_string_no_hash(ll_chars, i, len(self.s))
        ch = ll_chars[i]
        if ch == '\\':
            self.pos = i
            return self.decode_string_escaped(start, nonascii)
        if ch < '\x20':
            self._raise_control_char_in_string(ch, start, i)
        else:
            assert ch == '"'

        self.pos = i + 1
        return self._create_string_wrapped(start, i, nonascii)

    def _create_string_wrapped(self, start, end, nonascii):
        content = self.getslice(start, end)
        if nonascii:
            # contains non-ascii chars, we need to check that it's valid utf-8
            lgt = unicodehelper.check_utf8_or_raise(self.space,
                                                          content)
        else:
            lgt = end - start
        return self.space.newutf8(content, lgt)

    def _create_dict(self, d):
        from pypy.objspace.std.dictmultiobject import from_unicode_key_dict
        return from_unicode_key_dict(self.space, d)

    def _create_empty_dict(self):
        from pypy.objspace.std.dictmultiobject import create_empty_unicode_key_dict
        return create_empty_unicode_key_dict(self.space)

    def decode_string_escaped(self, start, nonascii):
        i = self.pos
        builder = StringBuilder((i - start) * 2) # just an estimate
        assert start >= 0
        assert i >= 0
        builder.append_slice(self.s, start, i)
        while True:
            ch = self.ll_chars[i]
            i += 1
            if ch == '"':
                content_utf8 = builder.build()
                length = unicodehelper.check_utf8_or_raise(self.space,
                                                           content_utf8)
                self.pos = i
                return self.space.newutf8(content_utf8, length)
            elif ch == '\\':
                i = self.decode_escape_sequence_to_utf8(i, builder)
            elif ch < '\x20':
                self._raise_control_char_in_string(ch, start, i)
            else:
                builder.append(ch)

    def decode_escape_sequence_to_utf8(self, i, stringbuilder):
        ch = self.ll_chars[i]
        i += 1
        put = stringbuilder.append
        if ch == '\\':  put('\\')
        elif ch == '"': put('"' )
        elif ch == '/': put('/' )
        elif ch == 'b': put('\b')
        elif ch == 'f': put('\f')
        elif ch == 'n': put('\n')
        elif ch == 'r': put('\r')
        elif ch == 't': put('\t')
        elif ch == 'u':
            # may be a surrogate pair
            return self.decode_escape_sequence_unicode(i, stringbuilder)
        else:
            if ch <= ' ':
                self._raise("Invalid \\escape: (char %d)" % (i-2,), i-2)
            else:
                self._raise("Invalid \\escape: %s (char %d)" % (ch, i-2), i-2)
        return i

    def _get_int_val_from_hex4(self, i):
        ll_chars = self.ll_chars
        res = 0
        for i in range(i, i + 4):
            ch = ord(ll_chars[i])
            if ord('a') <= ch <= ord('f'):
                digit = ch - ord('a') + 10
            elif ord('A') <= ch <= ord('F'):
                digit = ch - ord('A') + 10
            elif ord('0') <= ch <= ord('9'):
                digit = ch - ord('0')
            else:
                raise ValueError
            res = (res << 4) + digit
        return res

    def decode_escape_sequence_unicode(self, i, builder):
        # at this point we are just after the 'u' of the \u1234 sequence.
        start = i
        i += 4
        try:
            val = self._get_int_val_from_hex4(start)
            if (0xd800 <= val <= 0xdbff and
                    self.ll_chars[i] == '\\' and self.ll_chars[i+1] == 'u'):
                lowsurr = self._get_int_val_from_hex4(i + 2)
                if 0xdc00 <= lowsurr <= 0xdfff:
                    # decode surrogate pair
                    val = 0x10000 + (((val - 0xd800) << 10) |
                                     (lowsurr - 0xdc00))
                    i += 6
        except ValueError:
            raise DecoderError("Invalid \uXXXX escape (char %d)", i-1)
            return # help the annotator to know that we'll never go beyond
                   # this point
        #
        utf8_ch = rutf8.unichr_as_utf8(r_uint(val), allow_surrogates=True)
        builder.append(utf8_ch)
        return i


    def decode_string(self, i, contextmap=None):
        """ Decode a string at position i (which is right after the opening ").
        Optionally pass a contextmap, if the value is decoded as the value of a
        dict."""

        ll_chars = self.ll_chars
        start = i
        ch = ll_chars[i]
        if ch == '"':
            self.pos = i + 1
            return self.w_empty_string # surprisingly common

        cache = True
        if contextmap is not None:
            # keep some statistics about the usefulness of the string cache on
            # the contextmap
            # the intuition about the contextmap is as follows:
            # often there are string values stored in dictionaries that can
            # never be usefully cached, like unique ids of objects. Then the
            # strings *in those fields* of all objects should never be cached.
            # However, the content of other fields can still be useful to
            # cache.
            contextmap.decoded_strings += 1
            if not contextmap.should_cache_strings():
                cache = False
        if len(self.s) < self.MIN_SIZE_FOR_STRING_CACHE:
            cache = False

        if not cache:
            return self.decode_string_uncached(i)

        strhash, nonascii, i = simd.find_end_of_string(ll_chars, i, len(self.s))
        ch = ll_chars[i]
        if ch == '\\':
            self.pos = i
            return self.decode_string_escaped(start, nonascii)
        if ch < '\x20':
            self._raise_control_char_in_string(ch, start, i)
        else:
            assert ch == '"'

        self.pos = i + 1

        length = i - start
        strhash ^= length

        # check cache first:
        try:
            entry = self.cache_values[strhash]
        except KeyError:
            w_res = self._create_string_wrapped(start, i, nonascii)
            # only add *some* strings to the cache, because keeping them all is
            # way too expensive. first we check if the contextmap has caching
            # disabled completely. if not, we check whether we have recently
            # seen the same hash already, if yes, we cache the string.
            if ((contextmap is not None and
                        contextmap.decoded_strings < self.STRING_CACHE_EVALUATION_SIZE) or
                    strhash in self.lru_cache):
                entry = StringCacheEntry(
                        self.getslice(start, start + length), w_res)
                self.cache_values[strhash] = entry
            else:
                self.lru_cache[self.lru_index] = strhash
                self.lru_index = (self.lru_index + 1) & self.LRU_MASK
            return w_res
        if not entry.compare(ll_chars, start, length):
            # collision! hopefully rare
            return self._create_string_wrapped(start, i, nonascii)
        if contextmap is not None:
            contextmap.cache_hits += 1
        return entry.w_uni

    def decode_key_map(self, i, currmap):
        """ Given the current map currmap of an object, decode the next key at
        position i. This returns the new map of the object. """
        newmap = self._decode_key_map(i, currmap)
        if newmap is None:
            return None
        currmap.observe_transition(newmap, self.startmap)
        return newmap

    def _decode_key_map(self, i, currmap):
        ll_chars = self.ll_chars
        # first try to see whether we happen to find currmap.nextmap_first
        nextmap = currmap.fast_path_key_parse(self, i)
        if nextmap is not None:
            return nextmap

        start = i
        ch = ll_chars[i]
        if ch != '"':
            raise DecoderError("Key name must be string at char", i)
        i += 1
        w_key = self._decode_key_string(i)
        return currmap.get_next(w_key, self.s, start, self.pos, self.startmap)

    def _decode_key_string(self, i):
        """ decode key at position i as a string. Key strings are always
        cached, since they repeat a lot. """
        ll_chars = self.ll_chars
        start = i

        strhash, nonascii, i = simd.find_end_of_string(ll_chars, i, len(self.s))

        ch = ll_chars[i]
        if ch == '\\':
            self.pos = i
            w_key = self.decode_string_escaped(start, nonascii)
            return w_key
        if ch < '\x20':
            self._raise_control_char_in_string(ch, start, i)
        length = i - start
        strhash ^= length
        self.pos = i + 1
        # check cache first:
        try:
            entry = self.cache_keys[strhash]
        except KeyError:
            w_res = self._create_string_wrapped(start, i, nonascii)
            entry = StringCacheEntry(
                    self.getslice(start, start + length), w_res)
            self.cache_keys[strhash] = entry
            return w_res
        if not entry.compare(ll_chars, start, length):
            # collision! hopefully rare
            w_res = self._create_string_wrapped(start, i, nonascii)
        else:
            w_res = entry.w_uni
        return w_res

    def decode_key_string(self, i):
        ll_chars = self.ll_chars
        ch = ll_chars[i]
        if ch != '"':
            self._raise("Key name must be string at char %d", i)
        i += 1
        return self._decode_key_string(i)


class StringCacheEntry(object):
    """ A cache entry, bundling the encoded version of a string as it appears
    in the input string, and its wrapped decoded variant. """
    def __init__(self, repr, w_uni):
        # repr is the escaped string
        self.repr = repr
        # uni is the wrapped decoded string
        self.w_uni = w_uni

    def compare(self, ll_chars, start, length):
        """ Check whether self.repr occurs at ll_chars[start:start+length] """
        if length != len(self.repr):
            return False
        index = start
        for c in self.repr:
            if not ll_chars[index] == c:
                return False
            index += 1
        return True


class MapBase(object):
    """ A map implementation to speed up parsing of json dicts, and to
    represent the resulting dicts more compactly and make access faster. """

    # the basic problem we are trying to solve is the following: dicts in
    # json can either be used as objects, or as dictionaries with arbitrary
    # string keys. We want to use maps for the former, but not for the
    # latter. But we don't know in advance which kind of dict is which.

    # Therefore we create "preliminary" maps where we aren't quite sure yet
    # whether they are really useful maps or not. If we see them used often
    # enough, we promote them to "useful" maps, which we will actually
    # instantiate objects with.

    # If we determine that a map is not used often enough, we can turn it
    # into a "blocked" map, which is a point in the map tree where we will
    # switch to regular dicts, when we reach that part of the tree.

    # One added complication: We want to keep the number of preliminary maps
    # bounded to prevent generating tons of useless maps. but also not too
    # small, to support having a json file that contains many uniform objects
    # with tons of keys. That's where the idea of "fringe" maps comes into
    # play. They are maps that sit between known useful nodes and preliminary
    # nodes in the map transition tree. We bound only the number of fringe
    # nodes we are considering (to MAX_FRINGE), but not the number of
    # preliminary maps. When we have too many fringe maps, we remove the least
    # commonly instantiated fringe map and mark it as blocked.

    # allowed graph edges or nodes in nextmap_all:
    #    USEFUL -------
    #   /      \       \
    #  v        v       v
    # FRINGE   USEFUL   BLOCKED
    #  |
    #  v
    # PRELIMINARY
    #  |
    #  v
    # PRELIMINARY

    # state transitions:
    #   PRELIMINARY
    #   /   |       \
    #   |   v        v
    #   | FRINGE -> USEFUL
    #   |   |
    #   \   |
    #    v  v
    #   BLOCKED

    # the nextmap_first edge can only be these graph edges:
    #  USEFUL
    #   |
    #   v
    #  USEFUL
    #
    #  FRINGE
    #   |
    #   v
    #  PRELIMINARY
    #   |
    #   v
    #  PRELIMINARY

    USEFUL = 'u'
    PRELIMINARY = 'p'
    FRINGE = 'f' # buffer between PRELIMINARY and USEFUL
    BLOCKED = 'b'

    # tunable parameters
    MAX_FRINGE = 40
    USEFUL_THRESHOLD = 5

    def __init__(self, space):
        self.space = space

        # a single transition is stored in .nextmap_first
        self.nextmap_first = None

        # nextmap_all is only initialized after seeing the *second* transition
        # but then it also contains .nextmap_first
        self.nextmap_all = None # later dict {key: nextmap}

        # keep some statistics about every map: how often it was instantiated
        # and how many non-blocked leaves the map transition tree has, starting
        # from self
        self.instantiation_count = 0
        self.number_of_leaves = 1

    def _check_invariants(self):
        if self.nextmap_all:
            for next in self.nextmap_all.itervalues():
                next._check_invariants()
        elif self.nextmap_first:
            self.nextmap_first._check_invariants()

    def get_next(self, w_key, string, start, stop, terminator):
        """ Returns the next map, given a wrapped key w_key, the json input
        string with positions start and stop, as well as a terminator.

        Returns None if the key already appears somewhere in the map chain.
        """
        from pypy.objspace.std.dictmultiobject import unicode_hash, unicode_eq
        if isinstance(self, JSONMap):
            assert not self.state == MapBase.BLOCKED
        nextmap_first = self.nextmap_first
        if (nextmap_first is not None and
                nextmap_first.w_key.eq_w(w_key)):
            return nextmap_first

        assert stop >= 0
        assert start >= 0

        if nextmap_first is None:
            # first transition ever seen, don't initialize nextmap_all
            next = self._make_next_map(w_key, string[start:stop])
            if next is None:
                return None
            self.nextmap_first = next
        else:
            if self.nextmap_all is None:
                # 2nd transition ever seen
                self.nextmap_all = objectmodel.r_dict(unicode_eq, unicode_hash,
                  force_non_null=True, simple_hash_eq=True)
                self.nextmap_all[nextmap_first.w_key] = nextmap_first
            else:
                next = self.nextmap_all.get(w_key, None)
                if next is not None:
                    return next
            # if we are at this point we didn't find the transition yet, so
            # create a new one
            next = self._make_next_map(w_key, string[start:stop])
            if next is None:
                return None
            self.nextmap_all[w_key] = next

            # one new leaf has been created
            self.change_number_of_leaves(1)

        terminator.register_potential_fringe(next)
        return next

    def change_number_of_leaves(self, difference):
        """ add difference to .number_of_leaves of self and its parents """
        if not difference:
            return
        parent = self
        while isinstance(parent, JSONMap):
            parent.number_of_leaves += difference
            parent = parent.prev
        parent.number_of_leaves += difference # terminator

    def fast_path_key_parse(self, decoder, position):
        """ Fast path when parsing the next key: We speculate that we will
        always see a commonly seen next key, and use strcmp (implemented in
        key_repr_cmp) to check whether that is the case. """
        nextmap_first = self.nextmap_first
        if nextmap_first:
            ll_chars = decoder.ll_chars
            assert isinstance(nextmap_first, JSONMap)
            if nextmap_first.key_repr_cmp(ll_chars, position):
                decoder.pos = position + len(nextmap_first.key_repr)
                return nextmap_first
        return None

    def observe_transition(self, newmap, terminator):
        """ observe a transition from self to newmap.
        This does a few things, including updating the self size estimate with
        the knowledge that one object transitioned from self to newmap.
        also it potentially decides that self should move to state USEFUL."""
        newmap.instantiation_count += 1
        if isinstance(self, JSONMap) and self.state == MapBase.FRINGE:
            if self.is_useful():
                self.mark_useful(terminator)

    def _make_next_map(self, w_key, key_repr):
        # Check whether w_key is already part of the self.prev chain
        # to prevent strangeness in the json dict implementation.
        # This is slow, but it should be rare to call this function.
        check = self
        while isinstance(check, JSONMap):
            if check.w_key._utf8 == w_key._utf8:
                return None
            check = check.prev
        return JSONMap(self.space, self, w_key, key_repr)

    def fill_dict(self, dict_w, values_w):
        """ recursively fill the dictionary dict_w in the correct order,
        reading from values_w."""
        raise NotImplementedError("abstract base")

    def _all_dot(self, output):
        identity = objectmodel.compute_unique_id(self)
        output.append('%s [shape=box%s];' % (identity, self._get_dot_text()))
        if self.nextmap_all:
            for w_key, value in self.nextmap_all.items():
                assert isinstance(value, JSONMap)
                if value is self.nextmap_first:
                    color = ", color=blue"
                else:
                    color = ""
                output.append('%s -> %s [label="%s"%s];' % (
                    identity, objectmodel.compute_unique_id(value), value.w_key._utf8, color))
                value._all_dot(output)
        elif self.nextmap_first is not None:
            value = self.nextmap_first
            output.append('%s -> %s [label="%s", color=blue];' % (
                identity, objectmodel.compute_unique_id(value), value.w_key._utf8))
            value._all_dot(output)


    def _get_dot_text(self):
        return ", label=base"

    def view(self):
        from dotviewer import graphclient
        import pytest
        r = ["digraph G {"]
        self._all_dot(r)
        r.append("}")
        p = pytest.ensuretemp("jsonmap").join("temp.dot")
        p.write("\n".join(r))
        graphclient.display_dot_file(str(p))


class Terminator(MapBase):
    """ The root node of the map transition tree. """
    def __init__(self, space):
        MapBase.__init__(self, space)
        # a set of all map nodes that are currently in the FRINGE state
        self.current_fringe = {}

    def register_potential_fringe(self, prelim):
        """ add prelim to the fringe, if its prev is either a Terminator or
        useful. """
        prev = prelim.prev
        if (isinstance(prev, Terminator) or
                isinstance(prev, JSONMap) and prev.state == MapBase.USEFUL):
            assert prelim.state == MapBase.PRELIMINARY
            prelim.state = MapBase.FRINGE

            if len(self.current_fringe) > MapBase.MAX_FRINGE:
                self.cleanup_fringe()
            self.current_fringe[prelim] = None

    def remove_from_fringe(self, former_fringe):
        """ Remove former_fringe from self.current_fringe. """
        assert former_fringe.state in (MapBase.USEFUL, MapBase.BLOCKED)
        del self.current_fringe[former_fringe]

    def cleanup_fringe(self):
        """ remove the least-instantiated fringe map and block it."""
        min_fringe = None
        min_avg = 1e200
        for f in self.current_fringe:
            assert f.state == MapBase.FRINGE
            avg = f.average_instantiation()
            if avg < min_avg:
                min_avg = avg
                min_fringe = f
        assert min_fringe
        min_fringe.mark_blocked(self)

    def fill_dict(self, dict_w, values_w):
        """ recursively fill the dictionary dict_w in the correct order,
        reading from values_w."""
        return 0

    def _check_invariants(self):
        for fringe in self.current_fringe:
            assert fringe.state == MapBase.FRINGE

class JSONMap(MapBase):
    """ A map implementation to speed up parsing """

    def __init__(self, space, prev, w_key, key_repr):
        MapBase.__init__(self, space)

        self.prev = prev
        self.w_key = w_key
        self.key_repr = key_repr

        self.state = MapBase.PRELIMINARY

        # key decoding stats
        self.decoded_strings = 0
        self.cache_hits = 0

        # for jsondict support
        self.key_to_index = None
        self.keys_in_order = None
        self.strategy_instance = None

    def __repr__(self):
        return "<JSONMap key_repr=%s #instantiation=%s #leaves=%s prev=%r>" % (
                self.key_repr, self.instantiation_count, self.number_of_leaves, self.prev)

    def _get_terminator(self): # only for _check_invariants
        while isinstance(self, JSONMap):
            self = self.prev
        assert isinstance(self, Terminator)
        return self

    def _check_invariants(self):
        assert self.state in (
            MapBase.USEFUL,
            MapBase.PRELIMINARY,
            MapBase.FRINGE,
            MapBase.BLOCKED,
        )

        prev = self.prev
        if isinstance(prev, JSONMap):
            prevstate = prev.state
        else:
            prevstate = MapBase.USEFUL

        if prevstate == MapBase.USEFUL:
            assert self.state != MapBase.PRELIMINARY
        elif prevstate == MapBase.PRELIMINARY:
            assert self.state == MapBase.PRELIMINARY
        elif prevstate == MapBase.FRINGE:
            assert self.state == MapBase.PRELIMINARY
        else:
            # if prevstate is BLOCKED, we shouldn't have recursed here!
            assert False, "should be unreachable"

        if self.state == MapBase.BLOCKED:
            assert self.nextmap_first is None
            assert self.nextmap_all is None
        elif self.state == MapBase.FRINGE:
            assert self in self._get_terminator().current_fringe

        MapBase._check_invariants(self)

    def mark_useful(self, terminator):
        """ mark self as useful, and also the most commonly instantiated
        children, recursively """
        was_fringe = self.state == MapBase.FRINGE
        assert self.state in (MapBase.FRINGE, MapBase.PRELIMINARY)
        self.state = MapBase.USEFUL
        if was_fringe:
            terminator.remove_from_fringe(self)
        # find the most commonly instantiated child, store it into
        # nextmap_first and mark it useful, recursively
        maxchild = self.nextmap_first
        if self.nextmap_all is not None:
            for child in self.nextmap_all.itervalues():
                if child.instantiation_count > maxchild.instantiation_count:
                    maxchild = child
        if maxchild is not None:
            maxchild.mark_useful(terminator)
            if self.nextmap_all:
                for child in self.nextmap_all.itervalues():
                    if child is not maxchild:
                        terminator.register_potential_fringe(child)
                self.nextmap_first = maxchild

    def mark_blocked(self, terminator):
        """ mark self and recursively all its children as blocked."""
        was_fringe = self.state == MapBase.FRINGE
        self.state = MapBase.BLOCKED
        if was_fringe:
            terminator.remove_from_fringe(self)
        if self.nextmap_all:
            for next in self.nextmap_all.itervalues():
                next.mark_blocked(terminator)
        elif self.nextmap_first:
            self.nextmap_first.mark_blocked(terminator)
        self.nextmap_first = None
        self.nextmap_all = None
        self.change_number_of_leaves(-self.number_of_leaves + 1)

    def is_state_blocked(self):
        return self.state == MapBase.BLOCKED

    def is_state_useful(self):
        return self.state == MapBase.USEFUL

    def average_instantiation(self):
        """ the number of instantiations, divided by the number of leaves. We
        want to favor nodes that have either a high instantiation count, or few
        leaves below it. """
        return self.instantiation_count / float(self.number_of_leaves)

    def is_useful(self):
        return self.average_instantiation() > self.USEFUL_THRESHOLD

    def should_cache_strings(self):
        """ return whether strings parsed in the context of this map should be
        cached. """
        # we should cache if either we've seen few strings so far (less than
        # STRING_CACHE_EVALUATION_SIZE), or if we've seen many, and the cache
        # hit rate has been high enough
        return not (self.decoded_strings > JSONDecoder.STRING_CACHE_EVALUATION_SIZE and
                self.cache_hits * JSONDecoder.STRING_CACHE_USEFULNESS_FACTOR < self.decoded_strings)

    def key_repr_cmp(self, ll_chars, i):
        # XXX should we use "real" memcmp (here in particular, and in other
        # places in RPython in general)?
        for j, c in enumerate(self.key_repr):
            if ll_chars[i] != c:
                return False
            i += 1
        return True

    def fill_dict(self, dict_w, values_w):
        index = self.prev.fill_dict(dict_w, values_w)
        dict_w[self.w_key] = values_w[index]
        return index + 1

    # _____________________________________________________
    # methods for JsonDictStrategy

    @jit.elidable
    def get_index(self, w_key):
        from pypy.objspace.std.unicodeobject import W_UnicodeObject
        assert isinstance(w_key, W_UnicodeObject)
        return self.get_key_to_index().get(w_key, -1)

    def get_key_to_index(self):
        from pypy.objspace.std.dictmultiobject import unicode_hash, unicode_eq
        key_to_index = self.key_to_index
        if key_to_index is None:
            key_to_index = self.key_to_index = objectmodel.r_dict(unicode_eq, unicode_hash,
                  force_non_null=True, simple_hash_eq=True)
            # compute depth
            curr = self
            depth = 0
            while True:
                depth += 1
                curr = curr.prev
                if not isinstance(curr, JSONMap):
                    break

            curr = self
            while depth:
                depth -= 1
                key_to_index[curr.w_key] = depth
                curr = curr.prev
                if not isinstance(curr, JSONMap):
                    break
        return key_to_index

    def get_keys_in_order(self):
        keys_in_order = self.keys_in_order
        if keys_in_order is None:
            key_to_index = self.get_key_to_index()
            keys_in_order = self.keys_in_order = [None] * len(key_to_index)
            for w_key, index in key_to_index.iteritems():
                keys_in_order[index] = w_key
        return keys_in_order

    # _____________________________________________________

    def _get_dot_text(self):
        if self.nextmap_all is None:
            l = int(self.nextmap_first is not None)
        else:
            l = len(self.nextmap_all)
        extra = ""
        if self.decoded_strings:
            extra = "\\n%s/%s (%s%%)" % (self.cache_hits, self.decoded_strings, self.cache_hits/float(self.decoded_strings))
        res = ', label="#%s\\nchildren: %s%s"' % (self.instantiation_count, l, extra)
        if self.state == MapBase.BLOCKED:
            res += ", fillcolor=lightsalmon"
        if self.state == MapBase.FRINGE:
            res += ", fillcolor=lightgray"
        if self.state == MapBase.PRELIMINARY:
            res += ", fillcolor=lightslategray"
        return res

@jit.dont_look_inside
def loads(space, w_s, w_errorcls=None):
    s = space.text_w(w_s)
    decoder = JSONDecoder(space, s)
    try:
        w_res = decoder.decode_any(0)
        i = decoder.skip_whitespace(decoder.pos)
        if i < len(s):
            start = i
            raise DecoderError('Extra data', start)
        return w_res
    except DecoderError as e:
        if w_errorcls is None:
            w_errorcls = space.w_ValueError
        w_e = space.call_function(w_errorcls, space.newtext(e.msg), w_s,
                                  space.newint(e.pos))
        raise OperationError(w_errorcls, w_e)
    finally:
        decoder.close()

