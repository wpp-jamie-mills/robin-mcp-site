#!/bin/bash
# AUTO-GENERATED: Published to GitHub Pages by CI on each tagged release.
# Do not edit the published copy — edit install.sh in the source repository instead.
#
# Installs robin-mcp as a Claude Desktop "mcpServers" entry (and prints the Claude Code command).
# robin-mcp is a Python/uv project run from a checkout — there is no .mcpb and nothing is put on your PATH.
#   curl -fsSL https://wpp-jamie-mills.github.io/robin-mcp-site/install.sh | bash
# Piped with no terminal to prompt on, it adds the Claude Desktop entry by default (a config backup is kept).
# To install WITHOUT touching Claude Desktop, set ROBIN_INSTALL_TTY=/dev/null and do not pass --yes:
#   curl -fsSL <same url> | ROBIN_INSTALL_TTY=/dev/null bash
# For an unattended install that DOES add the entry (agents/CI), pass --yes (and --install-uv if uv may be missing):
#   curl -fsSL <same url> | bash -s -- --yes
#
# Environment overrides (mainly for tests):
#   ROBIN_HOME          install folder (--dir wins; default ~/.robin-mcp)
#   ROBIN_INSTALL_BASE  base URL for the download files (default: the GitHub Pages site)
#   ROBIN_INSTALL_TTY   where prompts are read from (default /dev/tty); /dev/null = install only, never add the entry (unless --yes)
#   ROBIN_CLAUDE_CONFIG Claude Desktop config file (default ~/Library/Application Support/Claude/claude_desktop_config.json)
#   ROBIN_UV_PATH       colon-separated extra folders to look for uv in
#   ROBIN_INSTALL_NO_OPEN  1 = do not open Claude Desktop afterwards
set -euo pipefail

# Default download base (the prerelease copy is rewritten to point at /rc). Exactly one such line.
SITE_BASE_DEFAULT="https://wpp-jamie-mills.github.io/robin-mcp-site"
ENTRY_NAME="robin"  # the mcpServers key in claude_desktop_config.json
CLAUDE_BUNDLE_ID="com.anthropic.claudefordesktop"

if [[ -t 1 && -t 2 ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi
print_error() { printf '%b✗ %s%b\n' "$RED" "$1" "$NC" >&2; }
print_success() { printf '%b✓ %s%b\n' "$GREEN" "$1" "$NC"; }
print_warning() { printf '%b⚠ %s%b\n' "$YELLOW" "$1" "$NC"; }
print_step() { printf '%b→ %s%b\n' "$BLUE" "$1" "$NC"; }
die() { print_error "$1"; exit 1; }

ROBIN_TEMP_DIR=""
cleanup_temp() { [[ -n "$ROBIN_TEMP_DIR" && -d "$ROBIN_TEMP_DIR" ]] && rm -rf "$ROBIN_TEMP_DIR"; return 0; }

usage() {
  cat <<'EOF'
robin-mcp installer — adds robin-mcp as a Claude Desktop mcpServers entry (needs uv).

Usage:
  curl -fsSL https://wpp-jamie-mills.github.io/robin-mcp-site/install.sh | bash
  curl -fsSL <same url> | bash -s -- --dir "$HOME/Tools/robin-mcp"

Options:
  --dir <path>   Install folder (default: ~/.robin-mcp). Use the same folder when you update.
  --status       Print what is installed, the latest.version, and whether the entry is in Claude Desktop.
  --uninstall    Remove the install folder and the "robin" entry from Claude Desktop (asks first; add --yes with no terminal).
  --install-uv   If uv is missing, install it without asking (for agents).
  --no-open      Do not open Claude Desktop afterwards.
  --yes          Answer yes to adding/removing the Claude Desktop entry and to uninstalling.
  --help         Show this help.

Environment: ROBIN_HOME, ROBIN_INSTALL_BASE, ROBIN_INSTALL_TTY, ROBIN_CLAUDE_CONFIG, ROBIN_UV_PATH, ROBIN_INSTALL_NO_OPEN.
EOF
}

canonical_path() {
  local path="$1" rest="" dir
  while [[ ! -d "$path" ]]; do
    rest="/${path##*/}$rest"; path="${path%/*}"; [[ -n "$path" ]] || path="/"
  done
  dir="$(cd -P "$path" 2>/dev/null && pwd -P)" || return 1
  [[ "$dir" != "/" ]] || dir=""
  printf '%s%s\n' "$dir" "$rest"
}
lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
can_answer() { [[ "$ROBIN_INSTALL_TTY_PATH" != /dev/null ]] && { : <"$ROBIN_INSTALL_TTY_PATH"; } 2>/dev/null; }
ask_yes_no() {
  local reply=""
  can_answer || return 1
  printf '%s [y/N] ' "$1" >"$ROBIN_INSTALL_TTY_PATH"
  read -r reply <"$ROBIN_INSTALL_TTY_PATH" || return 1
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum <"$1" | awk '{ print $1 }'
  else shasum -a 256 <"$1" | awk '{ print $1 }'; fi
}

# robin-mcp ships one platform-independent source tarball.
artifact_name() { printf 'latest.tar.gz\n'; }

installed_version() {
  local dir="$1"
  [[ -f "$dir/installed.version" ]] && tr -d '[:space:]' <"$dir/installed.version"
}

# Find uv on PATH or in the usual spots; optionally install it.
find_uv() {
  local p
  if command -v uv >/dev/null 2>&1; then command -v uv; return 0; fi
  local IFS=:
  for p in ${ROBIN_UV_PATH:-} /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
    [[ -n "$p" && -x "$p/uv" ]] && { printf '%s\n' "$p/uv"; return 0; }
  done
  return 1
}
ensure_uv() {
  local uv
  if uv="$(find_uv)"; then printf '%s\n' "$uv"; return 0; fi
  if [[ "${1:-}" == install || "$INSTALL_UV" == true ]] || ask_yes_no "uv is not installed. Install it now (astral.sh uv installer)?"; then
    print_step "Installing uv…" >&2
    curl -fsSL https://astral.sh/uv/install.sh | sh >&2 || die "Could not install uv"
    uv="$(find_uv)" || die "uv installed but not found; add its folder to ROBIN_UV_PATH"
    printf '%s\n' "$uv"; return 0
  fi
  die "uv is required (https://docs.astral.sh/uv/). Install it, or re-run with --install-uv."
}

claude_config() { printf '%s\n' "${ROBIN_CLAUDE_CONFIG:-$HOME/Library/Application Support/Claude/claude_desktop_config.json}"; }

# Add or remove our mcpServers entry in claude_desktop_config.json, with a backup. Pure JS via osascript
# (no jq/node/python assumed). action=add needs $2=launcher; action=remove needs nothing more.
edit_entry() {
  local action="$1" launcher="${2:-}" config out js
  config="$(claude_config)"
  command -v osascript >/dev/null 2>&1 || { printf 'no-osascript\n'; return 0; }
  js="$(mktemp -t robin-entry.XXXXXX)"
  cat >"$js" <<'JXA'
function run() {
  const app = Application.currentApplication(); app.includeStandardAdditions = true;
  const fm = $.NSFileManager.defaultManager;
  const env = $.NSProcessInfo.processInfo.environment;
  const get = k => { const v = env.objectForKey(k); return v ? v.js : ""; };
  const action = get("ROBIN_ACTION"), name = get("ROBIN_ENTRY"), path = get("ROBIN_CFG"), cmd = get("ROBIN_CMD");
  const dir = path.replace(/\/[^/]*$/, "");
  fm.createDirectoryAtPathWithIntermediateDirectoriesAttributesError($(dir), true, $(), $());
  let data = {};
  if (fm.fileExistsAtPath($(path))) {
    const raw = $.NSString.stringWithContentsOfFileEncodingError($(path), $.NSUTF8StringEncoding, $()).js || "{}";
    try { data = JSON.parse(raw); } catch (e) { return "ERROR: existing config is not valid JSON; leaving it alone"; }
    if (typeof data !== "object" || data === null || Array.isArray(data)) return "ERROR: config is not a JSON object";
    // back up once per change
    const bak = path + ".robin-backup";
    $.NSString.stringWithString($(raw)).writeToFileAtomicallyEncodingError($(bak), true, $.NSUTF8StringEncoding, $());
  }
  if (!data.mcpServers || typeof data.mcpServers !== "object") data.mcpServers = {};
  if (action === "remove") {
    const e = data.mcpServers[name];
    if (!e) return "none";
    if (!e.command || e.command.indexOf("robin-mcp") === -1) return "other"; // not ours; leave it
    delete data.mcpServers[name];
  } else {
    data.mcpServers[name] = { command: cmd, args: [] };
  }
  const outStr = JSON.stringify(data, null, 2);
  const ok = $.NSString.stringWithString($(outStr)).writeToFileAtomicallyEncodingError($(path), true, $.NSUTF8StringEncoding, $());
  return ok ? "ok" : "ERROR: could not write the config file";
}
JXA
  out="$(ROBIN_ACTION="$action" ROBIN_ENTRY="$ENTRY_NAME" ROBIN_CFG="$config" ROBIN_CMD="$launcher" \
    osascript -l JavaScript "$js" 2>&1)" || true
  rm -f "$js"
  printf '%s\n' "$out"
}

entry_state() {
  local config launcher
  config="$(claude_config)"
  [[ -f "$config" ]] || { echo "missing"; return; }
  launcher="$1"
  if grep -q "\"$ENTRY_NAME\"" "$config" 2>/dev/null && grep -q "robin-mcp" "$config" 2>/dev/null; then
    echo "present"
  else
    echo "absent"
  fi
}

print_status() {
  local dir="$1" base="$2" installed latest launcher
  installed="$(installed_version "$dir" || true)"
  latest="$(curl -fsSL "$base/latest.version" 2>/dev/null | tr -d '[:space:]' || true)"
  launcher="$dir/current/bin/robin-mcp"
  echo "robin-mcp"
  echo "  Install folder:  $dir$([[ -d "$dir" ]] || echo " (missing)")"
  echo "  Installed:       ${installed:-not installed}"
  echo "  Latest:          ${latest:-unknown (could not reach $base)}"
  echo "  Launcher:        $launcher$([[ -x "$launcher" ]] || echo " (missing)")"
  echo "  Claude Desktop:  entry '$ENTRY_NAME' $(entry_state "$launcher") in $(claude_config)"
  if [[ -n "$installed" && -n "$latest" && "$installed" != "$latest" ]]; then
    echo "  Update available: run the install command again."
  fi
}

install_payload() {
  local file="$1" version="$2" dir="$3" uv="$4"
  local target="$dir/versions/${version:-unknown}" staging="$ROBIN_TEMP_DIR/unpacked"
  mkdir -p "$staging"
  tar -xzf "$file" -C "$staging" || die "Could not unpack the download"
  # The tarball may have a single top folder; find the one that holds pyproject.toml.
  local root
  root="$(find "$staging" -maxdepth 2 -name pyproject.toml -exec dirname {} \; | head -1)"
  [[ -n "$root" && -x "$root/bin/robin-mcp" ]] || die "The download does not look like robin-mcp (no bin/robin-mcp)"
  mkdir -p "$dir/versions"
  rm -rf "$target"
  mv "$root" "$target"
  ln -sfn "versions/${version:-unknown}" "$dir/current.new"
  mv -fT "$dir/current.new" "$dir/current" 2>/dev/null || { rm -rf "$dir/current"; mv "$dir/current.new" "$dir/current"; }
  print_step "Preparing the environment (uv sync)…"
  ( cd "$dir/current" && "$uv" sync --frozen --quiet ) || print_warning "uv sync did not finish; the first start will retry."
  # keep the two newest versions for rollback
  local old
  while IFS= read -r old; do
    [[ -n "$old" && "$old" != "${version:-unknown}" ]] && rm -rf "${dir:?}/versions/${old:?}"
  done < <(find "$dir/versions" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -t. -k1,1nr -k2,2nr -k3,3nr | tail -n +3)
}

main() {
  [[ -n "${HOME:-}" ]] || die "HOME is not set"
  local dir="" status_only=false uninstall=false yes=false no_open=false
  INSTALL_UV=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir) [[ $# -ge 2 && -n "$2" ]] || die "--dir needs a folder path"; dir="$2"; shift 2 ;;
      --dir=*) dir="${1#--dir=}"; [[ -n "$dir" ]] || die "--dir needs a folder path"; shift ;;
      --status) status_only=true; shift ;;
      --uninstall) uninstall=true; shift ;;
      --install-uv) INSTALL_UV=true; shift ;;
      --no-open) no_open=true; shift ;;
      --yes | -y) yes=true; shift ;;
      --help | -h) usage; exit 0 ;;
      *) die "Unknown argument: $1 (try --help)" ;;
    esac
  done

  local default_dir="${HOME%/}/.robin-mcp"
  [[ -n "$dir" ]] || dir="${ROBIN_HOME:-$default_dir}"
  if [[ "$dir" == \~ || "$dir" == \~/* ]]; then dir="$HOME${dir:1}"; fi
  dir="${dir%/}"
  [[ "$dir" == /* ]] || die "The install folder must be an absolute path: $dir"
  case "/$dir/" in */../* | */./*) die "The install folder cannot contain . or .. segments: $dir" ;; esac
  local canon canon_home p
  canon="$(lowercase "$(canonical_path "$dir")")" || die "Cannot resolve the install folder: $dir"
  canon_home="$(lowercase "$(canonical_path "$HOME")")" || die "Cannot resolve your home folder"
  [[ "$canon" != "$canon_home" ]] || die "Cannot use your home folder itself as the install folder"
  local user_tmp
  user_tmp="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)"
  if [[ -n "$user_tmp" ]]; then user_tmp="$(lowercase "$(canonical_path "${user_tmp%/}")")" || user_tmp=""; fi
  if [[ -z "$user_tmp" || "$user_tmp" == "/" || ("$canon" != "$user_tmp" && "$canon" != "$user_tmp/"*) ]]; then
    for p in /Applications /System /Library /usr /bin /sbin /etc /private/etc /var /opt; do
      [[ -d "$p" ]] || continue
      local canon_p; canon_p="$(lowercase "$(canonical_path "$p")")"
      if [[ "$canon" == "$canon_p" || "$canon" == "$canon_p/"* ]]; then die "Cannot use a system location: $dir"; fi
    done
  fi

  ROBIN_INSTALL_TTY_PATH="${ROBIN_INSTALL_TTY:-/dev/tty}"
  local base="${ROBIN_INSTALL_BASE:-$SITE_BASE_DEFAULT}"; base="${base%/}"
  local q_base q_dir status_cmd
  printf -v q_base '%q' "$base"; printf -v q_dir '%q' "$dir"
  status_cmd="curl -fsSL $q_base/install.sh | bash -s -- --status"
  [[ "$dir" == "$default_dir" ]] || status_cmd+=" --dir $q_dir"

  if [[ "$status_only" == true ]]; then print_status "$dir" "$base"; return 0; fi

  if [[ "$uninstall" == true ]]; then
    [[ -d "$dir" ]] || die "Nothing to remove: $dir does not exist"
    [[ -e "$dir/.robin-mcp-home" ]] || die "$dir is not a robin-mcp install folder; leaving it alone"
    if [[ "$yes" != true ]] && ! ask_yes_no "Remove $dir and the '$ENTRY_NAME' entry from Claude Desktop?"; then
      die "Not removed (with no terminal, add --yes)"
    fi
    local r; r="$(edit_entry remove)"; [[ "$r" == ERROR:* ]] && print_warning "Claude Desktop config: ${r#ERROR: }"
    rm -rf "${dir:?}"
    print_success "Removed robin-mcp (Claude Desktop entry: $r)"
    return 0
  fi

  echo ""; print_step "Installing robin-mcp"; echo ""
  print_step "Checking prerequisites…"
  local tool
  for tool in curl tar uname awk; do command -v "$tool" >/dev/null 2>&1 || die "$tool is not available"; done
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || die "Neither sha256sum nor shasum is available"
  local uv; uv="$(ensure_uv)"
  print_success "Prerequisites OK (uv: $uv)"

  if [[ -e "$dir" && ! -d "$dir" ]]; then die "Not a folder: $dir"; fi
  if [[ -d "$dir" ]]; then
    if [[ ! -e "$dir/.robin-mcp-home" && -n "$(find "$dir" -mindepth 1 -maxdepth 1 ! -name .DS_Store 2>/dev/null)" ]]; then
      die "That folder is not empty and is not a robin-mcp install folder: $dir"
    fi
    [[ -w "$dir" ]] || die "That folder is not writable: $dir"
  else
    mkdir -p "$dir" || die "Could not create $dir"; chmod 755 "$dir"
  fi
  touch "$dir/.robin-mcp-home"
  print_success "Install folder: $dir"

  ROBIN_TEMP_DIR="$(mktemp -d "$dir/.download.XXXXXX")" || die "Could not create a temporary folder"
  trap cleanup_temp EXIT

  local artifact; artifact="$(artifact_name)"
  print_step "Downloading the latest release…"
  curl -fsSL "$base/$artifact" -o "$ROBIN_TEMP_DIR/$artifact" || die "Download failed: $base/$artifact"
  curl -fsSL "$base/$artifact.sha256" -o "$ROBIN_TEMP_DIR/$artifact.sha256" || die "Download failed: $base/$artifact.sha256"
  local version=""
  if curl -fsSL "$base/latest.version" -o "$ROBIN_TEMP_DIR/latest.version" 2>/dev/null; then
    version="$(tr -d '[:space:]' <"$ROBIN_TEMP_DIR/latest.version")"
  fi
  [[ -z "$version" || "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die "The site's latest.version is not a version number"

  local expected actual
  expected="$(awk 'NR == 1 { print tolower($1) }' "$ROBIN_TEMP_DIR/$artifact.sha256")"
  actual="$(sha256_of "$ROBIN_TEMP_DIR/$artifact")"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ || "$expected" != "$actual" ]]; then
    print_error "Checksum mismatch — nothing was installed"
    print_error "Expected: ${expected:-<none>}   Got: $actual"
    print_error "A new release can take up to ~10 minutes to propagate; wait and run the installer again."
    exit 1
  fi
  print_success "Downloaded and verified${version:+ version $version}"

  local previous; previous="$(installed_version "$dir" || true)"
  install_payload "$ROBIN_TEMP_DIR/$artifact" "$version" "$dir" "$uv"
  [[ -n "$version" ]] && printf '%s\n' "$version" >"$dir/installed.version"
  if [[ -n "$previous" && "$previous" != "$version" ]]; then
    print_success "Updated from $previous to ${version:-the latest.version}"
  else
    print_success "Installed${version:+ version $version}"
  fi

  # Add the Claude Desktop mcpServers entry. Add it when: --yes; or the owner says yes at the prompt; or
  # we could not ask (no readable terminal) but the owner did not explicitly opt out. Wiring up Claude
  # Desktop is the whole point of this flow, so a non-interactive run (e.g. curl | bash with no /dev/tty)
  # adds the entry by default — edit_entry keeps a backup. Setting ROBIN_INSTALL_TTY=/dev/null is the
  # explicit "install only, do not touch Claude Desktop" opt-out.
  local launcher="$dir/current/bin/robin-mcp"
  local do_add=false default_add=""
  if [[ "$yes" == true ]]; then
    do_add=true
  elif can_answer; then
    ask_yes_no "Add robin-mcp to Claude Desktop (entry '$ENTRY_NAME')?" && do_add=true
  elif [[ "$ROBIN_INSTALL_TTY_PATH" != /dev/null ]]; then
    do_add=true; default_add=" (no terminal to ask on, so added by default; a backup was kept)"
  fi
  if [[ "$do_add" == true ]]; then
    local r; r="$(edit_entry add "$launcher")"
    if [[ "$r" == no-osascript ]]; then
      print_warning "Not on macOS (no osascript): skipped the Claude Desktop entry."
      echo "  Add an mcpServers entry \"$ENTRY_NAME\" with command: $launcher"
    elif [[ "$r" == ok ]]; then
      print_success "Added the '$ENTRY_NAME' entry to Claude Desktop.$default_add"
      if [[ "$no_open" != true && "${ROBIN_INSTALL_NO_OPEN:-}" != 1 ]]; then
        open -b "$CLAUDE_BUNDLE_ID" >/dev/null 2>&1 || true
      fi
    else
      print_warning "Did not change the Claude Desktop config: ${r#ERROR: }"
      print_warning "Add it by hand: an mcpServers entry \"$ENTRY_NAME\" with command $launcher"
    fi
  else
    print_warning "Skipped the Claude Desktop entry (ROBIN_INSTALL_TTY=/dev/null). Add it with --yes."
    echo "  mcpServers entry \"$ENTRY_NAME\": { \"command\": \"$launcher\" }"
  fi

  echo ""
  print_success "Done."
  echo "Claude Code users can instead run:"
  printf '  claude mcp add --scope user %s -- %q\n' "$ENTRY_NAME" "$launcher"
  echo "Check the install any time with:"
  echo "  $status_cmd"
}

main "$@"
