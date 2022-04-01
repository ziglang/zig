from . import support

def expand_template(template, name):
    return support.DefaultExtensionTemplate(template, name).expand()


def test_expand_template():
    expanded = expand_template("""
        @EXPORT(f)
        @EXPORT(g)
        some more C stuff
        @INIT
    """, name='mytest')
    defines_table = ['&f,', '&g,']
    defines = '\n        '.join(defines_table)
    init_code = support.DefaultExtensionTemplate.INIT_TEMPLATE % {
        'defines': defines,
        'legacy_methods': 'NULL',
        'name': 'mytest',
        'init_types': '',
    }
    assert expanded.rstrip() == f"""#include <hpy.h>

some more C stuff
{init_code}
""".rstrip()
