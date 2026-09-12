#!/bin/bash
set -e

VER=${1:-13}

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

echo "baking image for debian ${VER}"
cd "${SCRIPTPATH}/debian${VER}"
./bake.sh
