from pypy.interpreter import error
from rpython.rlib import rutf8, objectmodel

def parse_number(space, raw):
    from pypy.objspace.std.intobject import _string_to_int_or_long
    from pypy.objspace.std.floatobject import _string_to_float
    base = 10
    if raw.startswith("-"):
        negative = True
        raw = raw.lstrip("-")
    else:
        negative = False
    if raw.startswith("0"):
        if len(raw) > 2 and raw[1] in "Xx":
            base = 16
        elif len(raw) > 2 and raw[1] in "Bb":
            base = 2
        ## elif len(raw) > 2 and raw[1] in "Oo": # Fallback below is enough
        ##     base = 8
        elif len(raw) > 1:
            base = 8
        # strip leading characters
        i = 0
        limit = len(raw) - 1
        while i < limit:
            if base == 16 and raw[i] not in "0xX":
                break
            if base == 8 and raw[i] not in "0oO":
                break
            if base == 2 and raw[i] not in "0bB":
                break
            i += 1
        raw = raw[i:]
        if not raw[0].isdigit():
            raw = "0" + raw
    if negative:
        raw = "-" + raw
    # by construction this should not be able to fail: the tokenizer only
    # recognizes ascii characters as parts of a number
    if not objectmodel.we_are_translated():
        rutf8.check_ascii(raw)
    w_num_str = space.newtext(raw, len(raw))
    if raw[-1] in "jJ":
        tp = space.w_complex
        return space.call_function(tp, w_num_str)
    try:
        return _string_to_int_or_long(space, w_num_str, raw, base)
    except error.OperationError as e:
        if not e.match(space, space.w_ValueError):
            raise
        return space.newfloat(_string_to_float(space, w_num_str, raw))
