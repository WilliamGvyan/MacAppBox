#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/recommendation-check"
mkdir -p "$BUILD_DIR"

swiftc \
  "$ROOT_DIR/Sources/MacAppBox/Models/LauncherModels.swift" \
  "$ROOT_DIR/Sources/MacAppBox/Models/LaunchRecommendation.swift" \
  "$ROOT_DIR/Tests/RecommendationChecks/main.swift" \
  -o "$BUILD_DIR/recommendation-check"

"$BUILD_DIR/recommendation-check"
