#!/bin/bash

set -e

if [ $# -lt 3 ]; then
    echo "usage: $0 <zig executable> <zig repo root> <tmp output dir> [<kernel version>...]"
    exit 1
fi

ZIG=$1
ZIG_ROOT=$2
OUTPUT_ROOT=$3
shift 3

ARCH="$(uname -m)"
IOURING_TESTS_ROOT=$ZIG_ROOT/ci/io_uring
PATCH_ROOT=$IOURING_TESTS_ROOT/patches
KERNEL_CDN="https://cdn.kernel.org/pub/linux/kernel"
KEEP_DOWNLOADS=0
KEEP_KERNEL_TREES=0

test_kernel() {
    VERSIONS=$1
    PARENT=$2
    VERSION=$3
    shift 3
    PATCHES=$*

    if [[ "$VERSIONS" != "" ]] && [[ "$VERSIONS" != *"$VERSION"* ]]; then
        echo "Skipping unselected version $VERSION"
        return 0
    fi

    OUTPUT_PATH=$OUTPUT_ROOT/$VERSION
    mkdir -p $OUTPUT_PATH
    if [ ! -f $OUTPUT_PATH/bzImage ] || [ $IOURING_TESTS_ROOT/kernel.config -nt $OUTPUT_PATH/bzImage ]; then
        if [ ! -f $OUTPUT_PATH/linux-$VERSION.tar.xz ]; then
            echo "[zig/tests/io_uring/"$VERSION"] Downloading..."
            wget -nv -nc -O $OUTPUT_PATH/linux-$VERSION.tar.xz $KERNEL_CDN/$PARENT/linux-$VERSION.tar.xz
        fi

        if [ ! -d $OUTPUT_PATH/linux-$VERSION ]; then
            echo "[zig/tests/io_uring/"$VERSION"] Extracting..."
            tar -xf $OUTPUT_PATH/linux-$VERSION.tar.xz -C $OUTPUT_PATH
            cp $IOURING_TESTS_ROOT/kernel.config $OUTPUT_PATH/linux-$VERSION/.config
            for PATCH in $PATCHES; do
                echo "[zig/tests/io_uring/"$VERSION"] Applying $PATCH..."
                patch -d $OUTPUT_PATH/linux-$VERSION -p1 < $PATCH_ROOT/$PATCH.patch
            done
        fi

        echo "[zig/tests/io_uring/"$VERSION"] Building..."
        pushd $OUTPUT_PATH/linux-$VERSION > /dev/null
            make olddefconfig
            WERROR=0 make -j$(nproc)
        popd > /dev/null

        echo "[zig/tests/io_uring/"$VERSION"] Installing..."
        cp $OUTPUT_PATH/linux-$VERSION/arch/$ARCH/boot/bzImage $OUTPUT_PATH/bzImage
        cp $OUTPUT_PATH/linux-$VERSION/vmlinux $OUTPUT_PATH/vmlinux

        cp $OUTPUT_PATH/linux-$VERSION/scripts/decode_stacktrace.sh $OUTPUT_ROOT/decode_stacktrace.sh
        cp $OUTPUT_PATH/linux-$VERSION/scripts/decodecode $OUTPUT_ROOT/decodecode

        if [ $KEEP_DOWNLOADS == 0 ]; then
            rm -f $OUTPUT_PATH/linux-$VERSION.tar.xz
        fi
        if [ $KEEP_KERNEL_TREES == 0 ]; then
            rm -rf $OUTPUT_PATH/linux-$VERSION
        fi
    fi

    rm -f $OUTPUT_ROOT/alpine-diff.qcow2
    qemu-img create -f qcow2 -b $OUTPUT_ROOT/alpine.qcow2 -F qcow2 $OUTPUT_ROOT/alpine-diff.qcow2 > /dev/null

    TIMEOUT_ERRC=124
    rm -f $OUTPUT_PATH/output.tests.log
    rm -f $OUTPUT_PATH/output.full.log

    set +e
    timeout --foreground --signal=SIGINT 60s qemu-system-x86_64 -M microvm,x-option-roms=off,isa-serial=off,rtc=off \
        -no-acpi -enable-kvm -cpu host -nodefaults -no-user-config -nographic -no-reboot \
        -m 512 -smp 4 \
        -device virtio-serial-device \
        -chardev stdio,id=virtiocon0 -device virtconsole,chardev=virtiocon0 \
        -drive id=root,file=$OUTPUT_ROOT/alpine-diff.qcow2,format=qcow2,if=none -device virtio-blk-device,drive=root \
        -device virtio-rng-device \
        -fsdev local,path=$OUTPUT_ROOT,security_model=none,id=hostfiles -device virtio-9p-device,fsdev=hostfiles,mount_tag=hostfiles \
        -kernel $OUTPUT_PATH/bzImage -append "console=hvc0 root=/dev/vda rw acpi=off reboot=t panic=-1" \
        > $OUTPUT_PATH/output.full.log
    if [[ $? == $TIMEOUT_ERRC ]]; then
        echo "[zig/tests/io_uring/"$VERSION"] Test timeout, displaying full log:"
        echo >> $OUTPUT_PATH/output.full.log
        $OUTPUT_ROOT/decode_stacktrace.sh vmlinux auto < $OUTPUT_PATH/output.full.log
        exit 1
    fi
    set -e

    RESULT=`tail -1 $OUTPUT_PATH/output.tests.log`
    if [[ ! "$RESULT" == *"; 0 failed."* ]]; then
        echo "[zig/tests/io_uring/"$VERSION"] Test failed, displaying full log:"
        echo >> $OUTPUT_PATH/output.full.log
        $OUTPUT_ROOT/decode_stacktrace.sh vmlinux auto < $OUTPUT_PATH/output.full.log
        exit 1
    fi
    echo "[zig/tests/io_uring/"$VERSION"]" $RESULT
}

mkdir -p $OUTPUT_ROOT

if [ ! -f $OUTPUT_ROOT/init ] || [ $IOURING_TESTS_ROOT/init.zig -nt $OUTPUT_ROOT/init ]; then
    $ZIG build-exe --enable-cache -static -femit-bin=$OUTPUT_ROOT/init $IOURING_TESTS_ROOT/init.zig
fi

if [ ! -f $OUTPUT_ROOT/alpine.qcow2 ] || [ $IOURING_TESTS_ROOT/build.dockerfile -nt $OUTPUT_ROOT/alpine.qcow2 ] || [ $OUTPUT_ROOT/init -nt $OUTPUT_ROOT/alpine.qcow2 ]; then
    echo "[zig/tests/io_uring] Building alpine.qcow2..."
    pushd $OUTPUT_ROOT > /dev/null
        DOCKER_BUILDKIT=1 docker build -f $IOURING_TESTS_ROOT/build.dockerfile --output "type=tar,dest=alpine.tar" .
        virt-make-fs --format=qcow2 --size=+200M alpine.tar alpine-large.qcow2
        qemu-img convert alpine-large.qcow2 -O qcow2 alpine.qcow2
        rm alpine-large.qcow2
        rm alpine.tar
    popd > /dev/null
fi

$ZIG test --enable-cache -static -femit-bin=$OUTPUT_ROOT/io_uring_tests --test-no-exec $ZIG_ROOT/lib/std/os/linux/io_uring.zig --zig-lib-dir $ZIG_ROOT/lib --main-pkg-path $ZIG_ROOT/lib/std

# Ensure they work on the host before atempting to run it on the vms
$OUTPUT_ROOT/io_uring_tests

test_kernel "$*" v5.x 5.0.21 1d489151e9
test_kernel "$*" v5.x 5.1.21 1d489151e9
test_kernel "$*" v5.x 5.2.21 1d489151e9
test_kernel "$*" v5.x 5.3.18 1d489151e9
test_kernel "$*" v5.x 5.4.228
test_kernel "$*" v5.x 5.5.19 1d489151e9 missing_msg_name_assign
test_kernel "$*" v5.x 5.6.19 1d489151e9 missing_msg_name_assign
test_kernel "$*" v5.x 5.7.19 1d489151e9
test_kernel "$*" v5.x 5.8.18 1d489151e9
test_kernel "$*" v5.x 5.9.16 1d489151e9
test_kernel "$*" v5.x 5.10.162
test_kernel "$*" v5.x 5.11.22 disabled_flag_clear
test_kernel "$*" v5.x 5.12.19
test_kernel "$*" v5.x 5.13.19
test_kernel "$*" v5.x 5.14.21
test_kernel "$*" v5.x 5.15.86
test_kernel "$*" v5.x 5.16.20
test_kernel "$*" v5.x 5.17.15
test_kernel "$*" v5.x 5.18.19
test_kernel "$*" v5.x 5.19.17
test_kernel "$*" v6.x 6.0.17
test_kernel "$*" v6.x 6.1.3
