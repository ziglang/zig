import os
import subprocess
import sys
import sysconfig

def test_venv_of_venv(tmpdir):
    exe = os.path.split(sys.executable)[-1]
    subprocess.run([sys.executable, '-mvenv', str(tmpdir / 'venv1')])
    # 'bin' or 'Script'
    path = os.path.split(sysconfig.get_path('scripts'))[-1]
    subprocess.run([str(tmpdir / 'venv1' / path / exe),
                    '-mvenv', str(tmpdir / 'venv2')])
    
