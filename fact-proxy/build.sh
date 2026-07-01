#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"

export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
  # shellcheck source=/dev/null
  source "$SDKMAN_DIR/bin/sdkman-init.sh"
else
  echo "SDKMAN not found. Install from https://sdkman.io/ then run: sdk env install" >&2
  exit 1
fi

sdk env install
sdk env

java_candidate="$(sed -n 's/^java=//p' .sdkmanrc | head -1)"
if [[ -n "$java_candidate" && -d "$SDKMAN_DIR/candidates/java/$java_candidate" ]]; then
  export JAVA_HOME="$SDKMAN_DIR/candidates/java/$java_candidate"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

unset GRADLE_USER_HOME

java_version="$(java -version 2>&1 | head -1)"
echo "Using: $java_version"
case "$java_version" in
  *\"25.*) ;;
  *)
    echo "Expected Java 25 from .sdkmanrc. Run: sdk install java 25.0.3-tem && sdk env" >&2
    exit 1
    ;;
esac

if [[ ! -f gradle/wrapper/gradle-wrapper.jar ]]; then
  echo "Generating Gradle wrapper (one-time)..."
  if [[ -x .tools/gradle-8.12.1/bin/gradle ]]; then
    .tools/gradle-8.12.1/bin/gradle wrapper --gradle-version 9.6.1
  elif command -v gradle >/dev/null 2>&1; then
    gradle wrapper --gradle-version 9.6.1
  else
    sdk install gradle 9.6.1
    gradle wrapper --gradle-version 9.6.1
  fi
fi

chmod +x ./gradlew
./gradlew test bootJar --no-daemon "$@"

echo "Built: $(pwd)/build/libs/fact-proxy.jar"
