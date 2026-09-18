#!/usr/bin/env bash
# Validate, transpile, test, and build a Rails app with pinned Roundhouse/Spinel.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ROUNDHOUSE_DIR="$ROOT_DIR/roundhouse"
SPINEL_DIR="$ROOT_DIR/spinel"
ROUNDHOUSE_REV=b5cc3fb12eb3434be7691ca429b8bdb43107197a
SPINEL_REV=d10ef3dd50618b30359c26ebb128c4a58a8f44f9
TARGET=""
OUTPUT_DIR=""
RUN_TESTS=1

usage() {
  cat <<'EOF'
Usage:
  scripts/compile-rails-app.sh [options] RAILS_APP

Options:
  -t, --target TARGET   Output target: go, rust, or spinel
  -o, --output DIR      Output directory (must be empty or absent)
      --skip-tests      Build without running the emitted test suite
  -h, --help            Show this help

If --target is omitted in an interactive terminal, the script prompts for it.
The default output is artifacts/<rails-app-name>-<target>.

Examples:
  scripts/compile-rails-app.sh --target go ~/src/my-api
  scripts/compile-rails-app.sh -t rust -o /tmp/my-api-rust ./my-api
  scripts/compile-rails-app.sh -t spinel ./my-api
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' was not found. $2"
}

checkout_matches() {
  local directory=$1
  local revision=$2
  local actual

  [[ -d "$directory/.git" ]] || return 1
  actual=$(git -C "$directory" rev-parse HEAD 2>/dev/null) || return 1
  [[ "$actual" == "$revision" ]]
}

ensure_checkout() {
  local name=$1
  local url=$2
  local directory=$3
  local revision=$4

  if [[ -e "$directory" ]]; then
    if ! checkout_matches "$directory" "$revision"; then
      die "$name exists at $directory but is not the pinned revision $revision; move it aside or check out that revision"
    fi
    printf 'Using pinned %s checkout: %s\n' "$name" "$directory"
    return
  fi

  printf 'Installing %s at pinned revision %s...\n' "$name" "$revision"
  git clone "$url" "$directory"
  git -C "$directory" checkout --detach "$revision"
}

while (($#)); do
  case "$1" in
    -t|--target)
      (($# >= 2)) || die "$1 requires a value"
      TARGET=$2
      shift 2
      ;;
    -o|--output)
      (($# >= 2)) || die "$1 requires a value"
      OUTPUT_DIR=$2
      shift 2
      ;;
    --skip-tests)
      RUN_TESTS=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

(($# == 1)) || { usage >&2; exit 2; }

RAILS_DIR=$(realpath "$1")
[[ -d "$RAILS_DIR" ]] || die "Rails app directory does not exist: $RAILS_DIR"
[[ -f "$RAILS_DIR/Gemfile" && -f "$RAILS_DIR/config/application.rb" ]] || \
  die "$RAILS_DIR does not look like a Rails application (expected Gemfile and config/application.rb)"

if [[ -z "$TARGET" ]]; then
  [[ -t 0 ]] || die "--target is required when standard input is not interactive"
  printf 'Choose an output target:\n  1) spinel (Ruby compiled to a native binary)\n  2) go\n  3) rust\n> '
  read -r choice
  case "$choice" in
    1|spinel) TARGET=spinel ;;
    2|go) TARGET=go ;;
    3|rust) TARGET=rust ;;
    *) die "invalid target choice: $choice" ;;
  esac
fi

case "$TARGET" in
  go|rust|spinel) ;;
  *) die "unsupported target '$TARGET'; choose go, rust, or spinel" ;;
esac

if [[ -z "$OUTPUT_DIR" ]]; then
  app_name=$(basename "$RAILS_DIR")
  OUTPUT_DIR="$ROOT_DIR/artifacts/${app_name}-${TARGET}"
else
  mkdir -p "$(dirname "$OUTPUT_DIR")"
  OUTPUT_DIR=$(realpath -m "$OUTPUT_DIR")
fi

if [[ -d "$OUTPUT_DIR" ]] && [[ -n "$(find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  die "output directory is not empty: $OUTPUT_DIR (remove it or choose another --output)"
fi

need_command git "Install Git and retry."
need_command cargo "Install Rust 1.85 or newer (rustup is recommended) and retry."

ensure_checkout Roundhouse https://github.com/rubys/roundhouse.git "$ROUNDHOUSE_DIR" "$ROUNDHOUSE_REV"

printf 'Building Roundhouse...\n'
cargo build \
  --manifest-path "$ROUNDHOUSE_DIR/Cargo.toml" \
  --release \
  --bin roundhouse-check \
  --bin roundhouse

if [[ "$TARGET" == spinel ]]; then
  need_command make "Install make and a C/C++ toolchain, plus SQLite and jemalloc development headers."
  ensure_checkout Spinel https://github.com/matz/spinel.git "$SPINEL_DIR" "$SPINEL_REV"
  printf 'Building Spinel...\n'
  make -C "$SPINEL_DIR" deps
  make -C "$SPINEL_DIR" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '2')"
fi

CHECK="$ROUNDHOUSE_DIR/target/release/roundhouse-check"
ROUNDHOUSE="$ROUNDHOUSE_DIR/target/release/roundhouse"

printf 'Running strict Roundhouse compatibility check...\n'
"$CHECK" "$RAILS_DIR"

printf 'Emitting %s project to %s...\n' "$TARGET" "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
"$ROUNDHOUSE" --target "$TARGET" -o "$OUTPUT_DIR" "$RAILS_DIR"

case "$TARGET" in
  go)
    need_command go "Install Go 1.24 or newer and retry."
    (
      cd "$OUTPUT_DIR"
      go mod tidy
      if ((RUN_TESTS)); then go test ./...; fi
      go build -o server .
    )
    EXECUTABLE="$OUTPUT_DIR/server"
    ;;
  rust)
    (
      cd "$OUTPUT_DIR"
      if ((RUN_TESTS)); then cargo test; fi
      cargo build --release
    )
    EXECUTABLE="$OUTPUT_DIR/target/release/app"
    ;;
  spinel)
    (
      cd "$OUTPUT_DIR"
      if ((RUN_TESTS)); then PATH="$SPINEL_DIR/bin:$PATH" spin test; fi
      PATH="$SPINEL_DIR/bin:$PATH" CC="${CC:-clang}" spin build
    )
    mapfile -t spinel_binaries < <(find "$OUTPUT_DIR/build/bin" -maxdepth 1 -type f -executable -print)
    ((${#spinel_binaries[@]} == 1)) || die "build succeeded but could not identify one executable in $OUTPUT_DIR/build/bin"
    EXECUTABLE=${spinel_binaries[0]}
    ;;
esac

printf '\nBuild complete.\nTarget: %s\nProject: %s\nExecutable: %s\n' "$TARGET" "$OUTPUT_DIR" "$EXECUTABLE"
