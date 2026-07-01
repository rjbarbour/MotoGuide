#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
rm -rf .gradle-user .gradle build
echo "Removed local Gradle caches and build output."
