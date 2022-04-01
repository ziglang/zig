def formatter_parser(space, w_unicode):
    from pypy.objspace.std.newformat import unicode_template_formatter
    tformat = unicode_template_formatter(space, space.utf8_w(w_unicode))
    return tformat.formatter_parser()

def formatter_field_name_split(space, w_unicode):
    from pypy.objspace.std.newformat import unicode_template_formatter
    tformat = unicode_template_formatter(space, space.utf8_w(w_unicode))
    return tformat.formatter_field_name_split()

