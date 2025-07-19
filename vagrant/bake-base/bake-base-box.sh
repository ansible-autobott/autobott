#!/bin/bash
set -e

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")


# debian 12
echo baking image for debian 12
cd "${SCRIPTPATH}/debian12"
./bake.sh

