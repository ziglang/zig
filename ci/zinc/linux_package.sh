#!/bin/sh

. ./ci/zinc/linux_base.sh

cp LICENSE $RELEASE_STAGING/
cp zig-cache/langref.html $RELEASE_STAGING/docs/

# Remove the unnecessary bin dir in $prefix/bin/zig
mv $RELEASE_STAGING/bin/zig $RELEASE_STAGING/
rmdir $RELEASE_STAGING/bin

# Remove the unnecessary zig dir in $prefix/lib/zig/std/std.zig
mv $RELEASE_STAGING/lib/zig $RELEASE_STAGING/lib2
rmdir $RELEASE_STAGING/lib
mv $RELEASE_STAGING/lib2 $RELEASE_STAGING/lib

VERSION=$($RELEASE_STAGING/zig version)
BASENAME="zig-linux-$ARCH-$VERSION"
TARBALL="$BASENAME.tar.xz"
mv "$RELEASE_STAGING" "$BASENAME"
tar cfJ "$TARBALL" "$BASENAME"
ls -l "$TARBALL"

SHASUM=$(sha256sum $TARBALL | cut '-d ' -f1)
BYTESIZE=$(wc -c < $TARBALL)

MANIFEST="manifest.json"
touch $MANIFEST
echo "{\"tarball\": \"$TARBALL\"," >>$MANIFEST
echo "\"shasum\": \"$SHASUM\"," >>$MANIFEST
echo "\"size\": \"$BYTESIZE\"}" >>$MANIFEST

# Publish artifact.
s3cmd put -P --add-header="cache-control: public, max-age=31536000, immutable" "$TARBALL" s3://ziglang.org/builds/

# Publish manifest.
s3cmd put -P --add-header="cache-control: max-age=0, must-revalidate" "$MANIFEST" "s3://ziglang.org/builds/$ARCH-linux-$VERSION.json"

# Avoid leaking oauth token.
set +x

cd $WORKSPACE
./ci/srht/on_master_success "$VERSION" "$SRHT_OAUTH_TOKEN"

set -x

# Explicit exit helps show last command duration.
exit
