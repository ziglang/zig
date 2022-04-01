RAW_ENCODING = "utf-8"
ENCODING_ERROR_HANDLING = "replace"

try:
    unicode = unicode
    def ord_byte_index(b, index):
        return ord(b[index])
except NameError:
    unicode = str
    def ord_byte_index(b, index):
        return b[index]

def forceunicode(name):
    """ returns `name` as unicode, even if it wasn't before  """
    return name if isinstance(name, unicode) else name.decode(RAW_ENCODING, ENCODING_ERROR_HANDLING)


def forcestr(name):
    """ returns `name` as string, even if it wasn't before  """
    return name if isinstance(name, bytes) else name.encode(RAW_ENCODING, ENCODING_ERROR_HANDLING)


def tryencode(name):
    """ returns `name` as encoded string if it was unicode before """
    return name.encode(RAW_ENCODING, ENCODING_ERROR_HANDLING) if isinstance(name, unicode) else name
