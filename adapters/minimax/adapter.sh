#!/usr/bin/env bash
# =============================================================================
# adapters/minimax/adapter.sh - Mavis (MiniMax Code) Plugin V1 packaging
# =============================================================================
# Mavis / MiniMax Code reads a Plugin V1 package from <data-dir>/plugins/<name>/.
# The shape is a manifest at .minimax-plugin/plugin.json plus zero or more
# `*.mcp.json` launch configs and `skills/<skill>/SKILL.md` references.
#
# This adapter does NOT compile the per-command skill set the other adapters
# emit. Mavis plugins ship a single root skill (`obsidian-second-brain`) that
# summarises the 45 commands; the per-tool work is exposed through the
# stdio MCP server at `integrations/obsidian-mcp-server/server.py`, which
# the build copies verbatim from upstream.
#
# Per the Plugin V1 spec, the manifest `version` is packaging-local; it does
# NOT mirror the upstream `pyproject.toml` semver. We hardcode `0.0.0` so the
# emitted artifact has no per-user drift and each Mavis user can stamp their
# own packaging version on copy.
#
# The MCP `OBSIDIAN_VAULT_PATH` is templated as `<VAULT_PATH>` (no real path)
# so the emitted package contains no user-specific secrets.
# =============================================================================

MINIMAX_PLATFORM="minimax"
MINIMAX_DIR="minimax"
MINIMAX_MANIFEST_DIR=".minimax-plugin"
MINIMAX_MANIFEST="${MINIMAX_MANIFEST_DIR}/plugin.json"
MINIMAX_MCP_CONFIG="obsidian-second-brain.mcp.json"
MINIMAX_SKILL_DIR="skills/obsidian-second-brain"

# 1x1 transparent PNG, 67 bytes. Used only when upstream `media/icon.png` is
# absent (so the V1 spec's required `icon` field always resolves). Stored as
# a hex string so the adapter stays shell-only and avoids a binary blob.
MINIMAX_ICON_FALLBACK_HEX="89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000a49444154789c6300010000000500010d0a2db40000000049454e44ae426082"

adapter_build() {
  local src="$1" dst="$2"

  _minimax_emit_manifest     "$dst"
  _minimax_emit_mcp_config   "$dst"
  _minimax_emit_icon         "$src" "$dst"
  _minimax_emit_placeholder  "$dst"
  _minimax_copy_mcp_server   "$src" "$dst"
  _minimax_copy_skill        "$src" "$dst"
  _minimax_emit_install_md   "$dst"
}

# ── .minimax-plugin/plugin.json ─────────────────────────────────────────────
# The Plugin V1 manifest. `version: "0.0.0"` is intentional: each Mavis user
# stamps their own packaging version on copy, and a hardcoded 0.0.0 makes the
# emitted package byte-identical across runs (idempotency gate for the smoke
# test). `OBSIDIAN_VAULT_PATH` is templated as `<VAULT_PATH>` so the artifact
# has no per-user paths.
_minimax_emit_manifest() {
  local dst="$1"
  local out="$dst/$MINIMAX_MANIFEST"
  mkdir -p "$(dirname "$out")"
  cat > "$out" <<'EOF'
{
  "schemaVersion": 1,
  "name": "obsidian-second-brain",
  "displayName": "Obsidian Second Brain",
  "version": "0.0.0",
  "description": "Persistent memory + notes for Mavis, backed by an Obsidian vault. 46 commands plus a stdio MCP server exposing vault search, read, save and capture as native tools.",
  "author": "eugeniughelbur (upstream) — packaged for Mavis by fcojg",
  "icon": "icon.png",
  "category": "Productivity",
  "exampleQueries": [
    "Save this conversation to my Obsidian vault",
    "Find notes about [topic] in my second brain",
    "What did I learn this week?",
    "Research X and update my vault with the findings",
    "Create today's daily note and pull in overdue tasks"
  ],
  "apps": [],
  "mcpServers": [
    "obsidian-second-brain.mcp.json"
  ],
  "skills": [
    "skills/obsidian-second-brain/SKILL.md"
  ]
}
EOF
}

# ── obsidian-second-brain.mcp.json ──────────────────────────────────────────
# stdio MCP launch config. `OBSIDIAN_VAULT_PATH` is templated so users substitute
# their real vault at packaging time. The `mcp<2` pin matches the V1 ecosystem
# guidance and the local installed plugin shape.
_minimax_emit_mcp_config() {
  local dst="$1"
  local out="$dst/$MINIMAX_MCP_CONFIG"
  cat > "$out" <<'EOF'
{
  "schemaVersion": 1,
  "mcpServers": {
    "obsidian-second-brain": {
      "type": "stdio",
      "command": "uv",
      "args": [
        "run",
        "--with",
        "mcp<2",
        "python",
        "./integrations/obsidian-mcp-server/server.py"
      ],
      "env": {
        "OBSIDIAN_VAULT_PATH": "<VAULT_PATH>"
      },
      "description": "Obsidian Second Brain vault tools: obsidian_search, obsidian_read_note, obsidian_save_note, obsidian_capture. Operates on the vault path in OBSIDIAN_VAULT_PATH.",
      "timeout": 30000
    }
  }
}
EOF
}

# ── icon.png ────────────────────────────────────────────────────────────────
# Copy upstream `media/icon.png` if present (we want a real asset, not the
# fallback, when the upstream ships one). Otherwise emit a 1x1 transparent
# PNG from a hex string. The hex is split into 2-byte chunks so the `printf`
# escape fits the line length; the bytes are identical to a real 1x1 PNG.
_minimax_emit_icon() {
  local src="$1" dst="$2"
  local out="$dst/icon.png"
  if [[ -f "$src/media/icon.png" ]]; then
    cp -p "$src/media/icon.png" "$out"
    return
  fi
  printf '\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0a\x49\x44\x41\x54\x78\x9c\x63\x00\x01\x00\x00\x05\x00\x01\x0d\x0a\x2d\xb4\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82' > "$out"
}

# ── placeholder ─────────────────────────────────────────────────────────────
# V1 packages need a write-tool anchor so the runtime can create the parent
# directory even before any user file lands. Plain ASCII, no per-build drift.
_minimax_emit_placeholder() {
  local dst="$1"
  printf '%s\n' "placeholder to ensure write tool can create the parent" > "$dst/placeholder"
}

# ── integrations/obsidian-mcp-server/* ──────────────────────────────────────
# Copied verbatim from upstream. These are the Python MCP server the
# `obsidian-second-brain.mcp.json` launches.
_minimax_copy_mcp_server() {
  local src="$1" dst="$2"
  local src_dir="$src/integrations/obsidian-mcp-server"
  local dst_dir="$dst/integrations/obsidian-mcp-server"
  [[ -d "$src_dir" ]] || { echo "minimax adapter: missing $src_dir" >&2; return 1; }
  mkdir -p "$dst_dir"
  cp -p "$src_dir/server.py"   "$dst_dir/server.py"
  cp -p "$src_dir/vault_ops.py" "$dst_dir/vault_ops.py"
  cp -p "$src_dir/README.md"    "$dst_dir/README.md"
}

# ── skills/obsidian-second-brain/SKILL.md ───────────────────────────────────
# The single root skill. Copied verbatim from upstream so the V1 spec sees
# `name` and `description` frontmatter that already match the skill directory.
_minimax_copy_skill() {
  local src="$1" dst="$2"
  local src_file="$src/SKILL.md"
  local dst_dir="$dst/$MINIMAX_SKILL_DIR"
  [[ -f "$src_file" ]] || { echo "minimax adapter: missing $src_file" >&2; return 1; }
  mkdir -p "$dst_dir"
  cp -p "$src_file" "$dst_dir/SKILL.md"
}

# ── INSTALL.md ───────────────────────────────────────────────────────────────
# Per-platform install + usage notes. Other adapters (codex-cli, gemini-cli,
# opencode, pi, hermes, agent-skills) do not emit this file; we add it for
# minimax because the Plugin V1 install path is data-dir-specific and the
# generic README cannot cover it.
_minimax_emit_install_md() {
  local dst="$1"
  local out="$dst/INSTALL.md"
  cat > "$out" <<'EOF'
# obsidian-second-brain on Mavis (MiniMax Code)

This adapter ships the skill as a **MiniMax Code Plugin V1** package that lives
under the Mavis data directory. It exposes the 45 vault commands as a single
root skill plus a stdio MCP server for direct tool calls (`obsidian_search`,
`obsidian_read_note`, `obsidian_save_note`, `obsidian_capture`).

The vault is **not** bundled. You point the MCP server at any existing Obsidian
vault (or a freshly bootstrapped one) via the `OBSIDIAN_VAULT_PATH` env var.

## Prerequisites

- **Mavis (MiniMax Code)** installed and runnable. The Plugin picker reads
  `~/.minimax/plugins/` (Windows: `%USERPROFILE%\.minimax\plugins\`).
- **`uv`** on PATH (the MCP server launches with `uv run --with mcp<2 ...`).
  Install from <https://docs.astral.sh/uv/>.
- **An Obsidian vault** anywhere on disk. The adapter does not create or
  bootstrap one for you; if you do not have one, use the upstream
  `python scripts/bootstrap_vault.py --preset default /path/to/vault` first.

## Build

```bash
git clone https://github.com/frandev94/obsidian-second-brain
cd obsidian-second-brain
bash scripts/build.sh --platform minimax
```

The artifact lands at `dist/minimax/`:

```
.minimax-plugin/
    plugin.json                          # Plugin V1 manifest
obsidian-second-brain.mcp.json           # stdio MCP launch config
icon.png                                # 1x1 PNG (placeholder; replace with your own)
placeholder                             # write-tool anchor
integrations/
    obsidian-mcp-server/
        server.py                       # MCP server (obsidian_search, etc.)
        vault_ops.py
        README.md
skills/
    obsidian-second-brain/
        SKILL.md                        # root skill (46 commands summarized)
INSTALL.md                              # this file
```

## Install

```bash
# 1. Drop the package into the Mavis data dir
mkdir -p "$HOME/.minimax/plugins/obsidian-second-brain"
cp -R dist/minimax/. "$HOME/.minimax/plugins/obsidian-second-brain/"

# 2. Point the MCP server at your vault (pick ONE of the two options)

# 2a. Export the env var globally (Linux/macOS: ~/.bashrc / ~/.zshrc;
#     Windows: System Properties → Environment Variables, or set in your
#     shell before launching Mavis).
export OBSIDIAN_VAULT_PATH="/absolute/path/to/your/vault"

# 2b. Or edit the installed .mcp.json and replace <VAULT_PATH> with your
#     real vault path:
#     $HOME/.minimax/plugins/obsidian-second-brain/obsidian-second-brain.mcp.json
#     "OBSIDIAN_VAULT_PATH": "C:\\Users\\you\\Documents\\vault"
```

Then **restart Mavis**. The plugin shows up in the Plugin picker as
"Obsidian Second Brain" (displayName from the manifest). The 45 commands are
discovered from `skills/obsidian-second-brain/SKILL.md`.

## Verify

1. Open Mavis and pick the "Obsidian Second Brain" plugin.
2. From the chat, ask: *"What commands does this skill expose?"* — you should
   get the 45-command summary from the root skill.
3. Ask: *"Search my vault for 'foo'"* — the agent should call
   `obsidian_search` against your vault and return real notes (or empty
   results if your vault is empty).
4. Ask: *"Save this conversation to my vault"* — the agent should call
   `obsidian_save_note` and write a new note under your vault's `Inbox/`
   with an `## For future agent` preamble and AI-first frontmatter.

If step 2 returns nothing, the skill is not loading — check Mavis's plugin
list. If step 3 fails, the MCP server cannot reach your vault — check
`OBSIDIAN_VAULT_PATH` (no trailing slash, absolute path, and the directory
exists).

## Updating

```bash
cd obsidian-second-brain
git pull
bash scripts/build.sh --platform minimax
rm -rf "$HOME/.minimax/plugins/obsidian-second-brain"/*
cp -R dist/minimax/. "$HOME/.minimax/plugins/obsidian-second-brain/"
```

Then restart Mavis. The MCP server's `uv run --with mcp<2` resolves the
MCP SDK on every launch, so Python deps do not need a separate update step.

## Uninstall

```bash
rm -rf "$HOME/.minimax/plugins/obsidian-second-brain"
```

Then restart Mavis. Your vault is **not** touched.

## Troubleshooting

- **`uv: command not found`** when Mavis launches the MCP server. Install
  `uv` and ensure it is on the PATH Mavis uses (on Windows, the PATH
  inherited from the user session, not the per-app PATH).
- **MCP server starts but every call fails with "vault path does not
  exist"**. `OBSIDIAN_VAULT_PATH` is empty, relative, or points at a
  directory that does not exist. Re-check the env var in the same shell
  Mavis is launched from, or hardcode it in `.mcp.json`.
- **Plugin shows in the picker but the skill is empty**. The build
  artifact is incomplete — re-run `bash scripts/build.sh --platform
  minimax` and confirm `dist/minimax/skills/obsidian-second-brain/SKILL.md`
  exists before copying.
- **Windows path backslashes**. The MCP config uses POSIX-style paths in
  its `args`. The `OBSIDIAN_VAULT_PATH` value can be either POSIX
  (`/c/Users/you/vault`) or Windows (`C:\\Users\\you\\vault`) — both work
  because `server.py` normalises via `pathlib.Path`.
EOF
}
