#!/bin/sh

# https://docs.drone.io/pipeline/docker/syntax/workspace/
#
# Drone automatically creates a temporary volume, known as your workspace,
# where it clones your repository. The workspace is the current working
# directory for each step in your pipeline.
#
# Because the workspace is a volume, filesystem changes are persisted between
# pipeline steps. In other words, individual steps can communicate and share
# state using the filesystem.
#
# Workspace volumes are ephemeral. They are created when the pipeline starts
# and destroyed after the pipeline completes.

set -x
set -e

ARCH="$(uname -m)"

DEPS_LOCAL="/deps/local"
WORKSPACE="$DRONE_WORKSPACE"

DEBUG_STAGING="$WORKSPACE/_debug/staging"
RELEASE_STAGING="$WORKSPACE/_release/staging"

export PATH=$DEPS_LOCAL/bin:$PATH
