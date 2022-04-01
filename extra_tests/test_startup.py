
def test_platform_not_imported():
    import subprocess
    import sys
    out = subprocess.check_output([sys.executable, '-c',
         'import sys; print(list(sys.modules.keys()))'], universal_newlines=True)
    modules = [x.strip(' "\'') for x in out.strip().strip('[]').split(',')]
    assert 'platform' not in modules
    assert 'threading' not in modules
