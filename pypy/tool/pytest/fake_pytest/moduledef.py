from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    applevel_name = 'pytest'
    interpleveldefs = {
        'raises': 'interp_pytest.pypyraises',
        'skip': 'interp_pytest.pypyskip',
        'fixture': 'interp_pytest.fake_fixture',

        # a bunch of things for assert rewriting
        'ar_saferepr': 'interp_arutil.saferepr',
        'ar_format_assertmsg': 'interp_arutil.format_assertmsg',
        'ar_format_explanation': 'interp_arutil.format_explanation',
        'ar_should_repr_global_name': 'interp_arutil.should_repr_global_name',
        'ar_format_boolop': 'interp_arutil.format_boolop',
        'ar_call_reprcompare': 'interp_arutil.call_reprcompare',
    }
    appleveldefs = {
        'importorskip': 'app_pytest.importorskip',
        'mark': 'app_pytest.mark',
    }
