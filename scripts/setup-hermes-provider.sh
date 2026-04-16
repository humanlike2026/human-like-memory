#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="@humanlikememory/human-like-mem-hermes-plugin"
PACKAGE_VERSION="${HUMANLIKE_PROVIDER_VERSION:-}"
PROFILE_HOME="${HERMES_HOME:-$HOME/.hermes}"
BUNDLE_DIR="${HUMANLIKE_BUNDLE_DIR:-$PROFILE_HOME/humanlike-memory-provider}"
WRITE_CONFIG=true
PYTHON_BIN=""
API_KEY_PRESENT=false

_c_reset=$'\033[0m'
_c_dim=$'\033[2m'
_c_blue=$'\033[38;5;33m'
_c_green=$'\033[38;5;78m'
_c_yellow=$'\033[38;5;214m'
_c_red=$'\033[38;5;203m'
_c_bold=$'\033[1m'

print_banner() {
  printf "\n%s%sHumanLike Memory Provider Setup%s\n" "$_c_bold" "$_c_blue" "$_c_reset"
  printf "%sInstall target:%s %s\n" "$_c_dim" "$_c_reset" "$BUNDLE_DIR"
  printf "%sHermes home:%s %s\n\n" "$_c_dim" "$_c_reset" "$PROFILE_HOME"
}

note() {
  printf "%s->%s %s\n" "$_c_blue" "$_c_reset" "$1"
}

ok() {
  printf "%s[ok]%s %s\n" "$_c_green" "$_c_reset" "$1"
}

warn() {
  printf "%s[warn]%s %s\n" "$_c_yellow" "$_c_reset" "$1"
}

die() {
  printf "%s[error]%s %s\n" "$_c_red" "$_c_reset" "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  bash setup-hermes-provider.sh
  bash setup-hermes-provider.sh --version 1.0.10
  bash setup-hermes-provider.sh --bundle-dir ~/.hermes/humanlike-memory-provider

Options:
  --version <ver>      Install a specific npm version instead of latest
  --bundle-dir <dir>   Where to unpack the provider bundle
  --profile-home <dir> Override Hermes profile home (default: ~/.hermes)
  --skip-config        Do not modify ~/.hermes/config.yaml
  -h, --help           Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        [[ $# -ge 2 ]] || die "--version requires a value"
        PACKAGE_VERSION="$2"
        shift 2
        ;;
      --bundle-dir)
        [[ $# -ge 2 ]] || die "--bundle-dir requires a value"
        BUNDLE_DIR="${2/#\~/$HOME}"
        shift 2
        ;;
      --profile-home)
        [[ $# -ge 2 ]] || die "--profile-home requires a value"
        PROFILE_HOME="${2/#\~/$HOME}"
        shift 2
        ;;
      --skip-config)
        WRITE_CONFIG=false
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

require_hermes_repo() {
  [[ -d "$PROFILE_HOME/hermes-agent" ]] || die "Hermes Agent was not found at $PROFILE_HOME/hermes-agent"
  ok "Hermes repository detected"
}

require_npm() {
  command -v npm >/dev/null 2>&1 || die "npm is required"
  ok "npm $(npm -v)"
}

resolve_python() {
  local hermes_bin shebang

  hermes_bin="$(command -v hermes 2>/dev/null || true)"
  if [[ -n "$hermes_bin" ]]; then
    shebang="$(head -1 "$hermes_bin" 2>/dev/null || true)"
    if [[ "$shebang" == "#!"*python* ]]; then
      PYTHON_BIN="${shebang#\#!}"
    fi
  fi

  if [[ -z "$PYTHON_BIN" || ! -x "$PYTHON_BIN" ]]; then
    if [[ -x "$PROFILE_HOME/hermes-agent/venv/bin/python3" ]]; then
      PYTHON_BIN="$PROFILE_HOME/hermes-agent/venv/bin/python3"
    elif command -v python3 >/dev/null 2>&1; then
      PYTHON_BIN="$(command -v python3)"
    else
      die "python3 was not found"
    fi
  fi

  ok "Hermes Python: $PYTHON_BIN"
}

check_api_key() {
  local env_file

  env_file="$PROFILE_HOME/.env"
  if [[ -f "$env_file" ]] && grep -q '^HUMAN_LIKE_MEM_API_KEY=' "$env_file"; then
    API_KEY_PRESENT=true
    ok "Detected HUMAN_LIKE_MEM_API_KEY in $env_file"
    return
  fi

  warn "HUMAN_LIKE_MEM_API_KEY is not set in $env_file yet"
}

resolve_version() {
  if [[ -n "$PACKAGE_VERSION" ]]; then
    return
  fi

  PACKAGE_VERSION="$(npm view "$PACKAGE_NAME" dist-tags.latest 2>/dev/null || true)"
  if [[ -z "$PACKAGE_VERSION" ]]; then
    PACKAGE_VERSION="$(npm view "$PACKAGE_NAME" version 2>/dev/null || true)"
  fi
  [[ -n "$PACKAGE_VERSION" ]] || die "Could not resolve a version for $PACKAGE_NAME"
}

fetch_bundle_from_registry() {
  local stage archive parent_dir cleanup_cmd

  resolve_version
  stage="$(mktemp -d)"
  cleanup_cmd="rm -rf '$stage'"
  trap "$cleanup_cmd" EXIT

  note "Fetching $PACKAGE_NAME@$PACKAGE_VERSION from npm"
  (
    cd "$stage"
    npm pack "$PACKAGE_NAME@$PACKAGE_VERSION" --loglevel=error >/dev/null
  )

  archive="$(find "$stage" -maxdepth 1 -name '*.tgz' | head -1)"
  [[ -n "$archive" && -f "$archive" ]] || die "npm pack did not produce a tarball"

  mkdir -p "$stage/unpacked"
  tar xzf "$archive" -C "$stage/unpacked"
  [[ -d "$stage/unpacked/package" ]] || die "The npm tarball did not contain a package directory"

  parent_dir="$(dirname "$BUNDLE_DIR")"
  mkdir -p "$parent_dir"
  rm -rf "$BUNDLE_DIR"
  mv "$stage/unpacked/package" "$BUNDLE_DIR"

  ok "Bundle unpacked to $BUNDLE_DIR"
}

find_memory_plugin_dir() {
  local plugin_dir

  plugin_dir="$("$PYTHON_BIN" -c "from pathlib import Path; import plugins.memory as pm; print(Path(pm.__file__).parent)" 2>/dev/null || true)"
  if [[ -n "$plugin_dir" && -d "$plugin_dir" ]]; then
    printf "%s" "$plugin_dir"
    return
  fi

  if [[ -d "$PROFILE_HOME/hermes-agent/plugins/memory" ]]; then
    printf "%s" "$PROFILE_HOME/hermes-agent/plugins/memory"
    return
  fi

  die "Failed to locate Hermes plugins/memory directory"
}

wire_provider() {
  local memory_dir provider_src provider_link verify_status

  memory_dir="$(find_memory_plugin_dir)"
  provider_src="$BUNDLE_DIR/adapters/hermes"
  provider_link="$memory_dir/humanlike"

  [[ -d "$provider_src" ]] || die "Provider adapter was not found: $provider_src"

  rm -rf "$provider_link"
  ln -s "$provider_src" "$provider_link"
  ok "Linked provider into $provider_link"

  verify_status="$("$PYTHON_BIN" -c "from plugins.memory import load_memory_provider; provider = load_memory_provider('humanlike'); print('ready' if provider and provider.name == 'humanlike' else 'missing')" 2>/dev/null || true)"
  if [[ "$verify_status" == "ready" ]]; then
    ok "Hermes can import the humanlike provider"
  else
    warn "Hermes did not confirm provider import; please verify manually"
  fi
}

write_config_yaml() {
  local config_file result

  $WRITE_CONFIG || {
    warn "Skipping config.yaml update because --skip-config was used"
    return
  }

  config_file="$PROFILE_HOME/config.yaml"
  mkdir -p "$PROFILE_HOME"

  result="$(
    PROFILE_HOME="$PROFILE_HOME" "$PYTHON_BIN" - <<'PYEOF'
import os
from pathlib import Path

import yaml

home = Path(os.environ["PROFILE_HOME"]).expanduser()
config_file = home / "config.yaml"

if config_file.exists():
    data = yaml.safe_load(config_file.read_text(encoding="utf-8")) or {}
else:
    data = {}

memory_cfg = data.get("memory")
if not isinstance(memory_cfg, dict):
    memory_cfg = {}
data["memory"] = memory_cfg
memory_cfg["provider"] = "humanlike"
memory_cfg.setdefault("memory_enabled", True)
memory_cfg.setdefault("user_profile_enabled", True)

config_file.write_text(
    yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False),
    encoding="utf-8",
)

written = yaml.safe_load(config_file.read_text(encoding="utf-8")) or {}
print("updated" if written.get("memory", {}).get("provider") == "humanlike" else "failed")
PYEOF
  )"

  if [[ "$result" == "updated" ]]; then
    ok "Updated $config_file"
  else
    warn "Could not confirm config.yaml update"
  fi
}

show_finish_notes() {
  printf "\n%s%sSetup complete%s\n" "$_c_bold" "$_c_green" "$_c_reset"
  printf "%sBundle:%s %s\n" "$_c_dim" "$_c_reset" "$BUNDLE_DIR"
  printf "%sProvider:%s humanlike\n" "$_c_dim" "$_c_reset"
  printf "%sHermes config:%s %s/config.yaml\n" "$_c_dim" "$_c_reset" "$PROFILE_HOME"
  printf "\nNext:\n"
  if $API_KEY_PRESENT; then
    printf "  1. HUMAN_LIKE_MEM_API_KEY is already configured\n"
  else
    printf "  1. Add your API key to %s/.env\n" "$PROFILE_HOME"
  fi
  printf "  2. Restart Hermes gateway if it is already running:\n"
  printf "     %shermes gateway restart%s\n" "$_c_bold" "$_c_reset"
  printf "  3. Restart the current Hermes CLI session if needed\n\n"
}

main() {
  parse_args "$@"
  print_banner
  require_hermes_repo
  require_npm
  resolve_python
  check_api_key
  fetch_bundle_from_registry
  wire_provider
  write_config_yaml
  show_finish_notes
}

main "$@"
