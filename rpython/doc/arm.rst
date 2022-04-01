.. _arm:

Cross-translating for ARM
=========================

.. note::

  The information here is unfortunately only of historical value. Scratchbox is
  no longer functional. However it seems translation of ARM32 is possible on a
  aarch64 machine using chroot and ``setarch linux32 pypy rpython/bin/rpython
  ...``

Here we describe the setup required and the steps needed to follow to translate
an interpreter using the RPython translator to target ARM using a cross
compilation toolchain.

To translate an RPython program for ARM we can either
translate directly on an ARM device following the normal translation steps.
Unfortunately this is not really feasible on most ARM machines. The
alternative is to cross-translate using a cross-compilation toolchain.

To cross-translate we run the translation on a more powerful (usually
x86) machine and generate a binary for ARM using a cross-compiler to compile
the generated C code. There are several constraints when doing this. In
particular we currently only support Linux as translation host and target
platforms (tested on Ubuntu). Also we need a 32-bit environment to run the
translation. This can be done either on a 32bit host or in 32bit chroot.


Requirements
------------

The tools required to cross translate from a Linux based host to an ARM based Linux target are:

- A checkout of PyPy (default branch).
- The GCC ARM cross compiler (on Ubuntu it is the ``gcc-arm-linux-gnueabi package``) but other
  toolchains should also work.
- Scratchbox 2, a cross-compilation engine (``scratchbox2`` Ubuntu package).
- A 32-bit PyPy or Python.
- And the following (or corresponding) packages need to be installed to create an ARM based chroot:

  * ``debootstrap``
  * ``schroot``
  * ``binfmt-support``
  * ``qemu-system``
  * ``qemu-user-static``

- The dependencies above are in addition to the ones needed for a regular
  translation, `listed here`_.

.. _`listed here`: http://pypy.readthedocs.org/en/latest/build.html#install-build-time-dependencies


Creating a Qemu based ARM chroot
--------------------------------

First we will need to create a rootfs containing the packages and dependencies
required in order to translate PyPy or other interpreters. We are going to
assume, that the files will be placed in ``/srv/chroot/precise_arm``.

Create the rootfs by calling:

::

   mkdir -p /srv/chroot/precise_arm
   qemu-debootstrap --variant=buildd --arch=armel precise /srv/chroot/precise_arm/  http://ports.ubuntu.com/ubuntu-ports/

Next, copy the qemu-arm-static binary to the rootfs.

::

  cp /usr/bin/qemu-arm-static /srv/chroot/precise_arm/usr/bin/qemu-arm-static

For easier configuration and management we will create a schroot pointing to
the rootfs. We need to add a configuration block (like the one below) to the
schroot configuration file in /etc/schroot/schroot.conf.


::

  [precise_arm]
  directory=/srv/chroot/precise_arm
  users=USERNAME
  root-users=USERNAME
  groups=users
  aliases=default
  type=directory


To verify that everything is working in the chroot, running ``schroot -c
precise_arm`` should start a shell running in the schroot environment using
qemu-arm to execute the ARM binaries. Running ``uname -m`` in the chroot should
yield a result like ``armv7l``. Showing that we are emulating an ARM system.

Start the schroot as the user root in order to configure the apt sources and
to install the following packages:

::

  schroot -c precise_arm -u root
  echo "deb http://ports.ubuntu.com/ubuntu-ports/ precise main universe restricted" > /etc/apt/sources.list
  apt-get update
  apt-get install libffi-dev libgc-dev python-dev build-essential libncurses5-dev libbz2-dev


Now all dependencies should be in place and we can exit the schroot environment.


Configuring scratchbox2
-----------------------

To configure the scratchbox we need to cd into the root directory of the rootfs
we created before. From there we can call the sb2 configuration tools which
will take the current directory as the base directory for the scratchbox2
environment.

::

  cd /srv/chroot/precise_arm
  sb2-init -c `which qemu-arm` ARM `which arm-linux-gnueabi-gcc`

This will create a scratchbox2 based environment called ARM that maps calls to
gcc done within the scratchbox to the arm-linux-gnueabi-gcc outside the
scratchbox. Now we should have a working cross compilation toolchain in place
and can start cross-translating programs for ARM.

Translation
-----------

Having performed all the preliminary steps we should now be able to cross
translate a program for ARM.  You can use this minimal
target to test your setup before applying it to a larger project.

Before starting the translator we need to set two environment variables, so the
translator knows how to use the scratchbox environment. We need to set the
**SB2** environment variable to point to the rootfs and the **SB2OPT** should
contain the command line options for the sb2 command. If our rootfs is in the
folder /srv/chroot/precise_arm and the scratchbox environment is called "ARM",
the variables would be defined as follows.

::

  export SB2=/srv/chroot/precise_arm
  export SB2OPT='-t ARM'

Once this is set, you can call the translator. For example save this file

::

  def main(args):
      print "Hello World"
      return 0

  def target(*args):
      return main, None

and call the translator

::

  pypy ~/path_to_pypy_checkout/rpython/bin/rpython -O2 --platform=arm target.py

If everything worked correctly this should yield an ARM binary. Running this
binary in the ARM chroot or on an ARM device should produce the output
``"Hello World"``.

To translate the full python pypy interpreter with a jit, you can cd into pypy/goal and call

::

  pypy <path to rpython>/rpython/bin/rpython -Ojit --platform=arm targetpypystandalone.py


