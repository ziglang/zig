Downloading and Installing PyPy
===============================

Using a packaged PyPy
~~~~~~~~~~~~~~~~~~~~~

Some Linux distributions provide a pypy package. Note that in order to
install additional modules that require compilation, you may need to install
additional packages such as pypy-dev. This will manifest as an error about
"missing Python.h". Distributions do not as of yet supply many pypy-ready
packages, if you require additional modules we recommend creating a virtualenv
and using pip. If you require compiled (c-extension) modules like SciPy, we
recommend you use conda, which works on Windows10, macOS, and linux x86_64:

.. code-block:: console

    $ conda create -my_cool_pypy pypy
    $ conda activate my_cool_pypy
    $ conda install scipy

On macOS you can also use homebrew, which provides signed packages.

.. _prebuilt-pypy:

Download a pre-built PyPy
~~~~~~~~~~~~~~~~~~~~~~~~~

The quickest way to start using PyPy is to download a prebuilt binary for your
OS and architecture.  You may be able to use either use the
`most recent release`_ or one of our `development nightly build`_. These
builds depend on dynamically linked libraries that may not be available on your
OS. See the section about `Linux binaries`_ for more info and alternatives that
may work on your system.

Please note that the nightly builds are not guaranteed to be as stable as
official releases, use them at your own risk. Also the macOS binaries are not
signed, which means you need to convince macOS they are safe for use.

.. _most recent release: https://pypy.org/download.html
.. _development nightly build: https://buildbot.pypy.org/nightly/trunk/
.. _Linux binaries: https://pypy.org/download.html#linux-binaries-and-common-distributions

Installing PyPy
~~~~~~~~~~~~~~~

PyPy is ready to be executed as soon as you unpack the tarball or the zip
file, with no need to install it in any specific location:

.. code-block:: console

    $ tar xf pypy-x.y.z.tar.bz2
    $ ./pypy-x.y.z/bin/pypy
    Python 2.7.x (xxxxxxxxxxxx, Date, Time)
    [PyPy x.y.z with GCC x.y.z] on linux2
    Type "help", "copyright", "credits" or "license" for more information.
    And now for something completely different: ``PyPy is an exciting technology
    that lets you to write fast, portable, multi-platform interpreters with less
    effort''
    >>>>

If you want to make PyPy available system-wide, you can put a symlink to the
``pypy`` executable in ``/usr/local/bin``.  It is important to put a symlink
and not move the binary there, else PyPy would not be able to find its
library.

Installing more modules
~~~~~~~~~~~~~~~~~~~~~~~

If you want to install 3rd party libraries, the most convenient way is
to install pip_ using ensurepip_ (unless you want to install virtualenv as 
explained below; then you can directly use pip inside virtualenvs):

.. code-block:: console

    $ ./pypy-xxx/bin/pypy -m ensurepip
    $ ./pypy-xxx/bin/pypy -mpip install -U pip wheel # to upgrade to the latest versions
    $ ./pypy-xxx/bin/pypy -mpip install pygments  # for example

If you wish to be able to use ``pip`` directly from the command line, you must
use the ``--default-pip`` argument when calling ``ensurepip``.
Third party libraries will be installed in ``pypy-xxx/site-packages``. As with
CPython, scripts on linux and macOS will be in ``pypy-xxx/bin``, and on windows
they will be in ``pypy-xxx/Scripts``


Installing using virtualenv
~~~~~~~~~~~~~~~~~~~~~~~~~~~

It is often convenient to run pypy inside a virtualenv.  To do this
you need a version of virtualenv -- 1.6.1 or greater.  You can
then install PyPy both from a precompiled tarball or from a mercurial
checkout after translation::

	# from a tarball
	$ virtualenv -p /opt/pypy-xxx/bin/pypy my-pypy-env

	# from the mercurial checkout
	$ virtualenv -p /path/to/pypy/pypy/translator/goal/pypy-c my-pypy-env

	# in any case activate it
	$ source my-pypy-env/bin/activate

Note that my-pypy-env/bin/python is now a symlink to my-pypy-env/bin/pypy
so you should be able to run pypy simply by typing::

    $ python

You should still upgrade pip and wheel to the latest versions via::

    $ my-pypy-env/bin/pypy -mpip install -U pip wheel

.. _pip: https://pypi.python.org/pypi/pip
.. _ensurepip: https://docs.python.org/3/library/ensurepip.html

Building PyPy yourself
~~~~~~~~~~~~~~~~~~~~~~

If you're interested in getting more involved, or doing something different with
PyPy, consult :doc:`the build instructions <build>`.
