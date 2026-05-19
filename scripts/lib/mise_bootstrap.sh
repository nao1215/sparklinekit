#!/bin/sh
# mise_bootstrap.sh -- Shared helper that makes mise-managed tools
# (erlang, gleam, rebar, node) visible on PATH without requiring the
# caller to have run `mise activate` in the current shell.

_sparklinekit_mise_prepend() {
  case ":${PATH-}:" in
    *":$1:"*) ;;
    *) PATH="$1${PATH:+:$PATH}" ;;
  esac
}

_SPARKLINEKIT_MISE_TOOLS="gleam escript erl rebar3 node"

sparklinekit_mise_bootstrap() {
  if [ -n "${HOME:-}" ] && [ -d "$HOME/.local/bin" ]; then
    _sparklinekit_mise_prepend "$HOME/.local/bin"
  fi

  if command -v mise >/dev/null 2>&1; then
    for _sparklinekit_bootstrap_tool in $_SPARKLINEKIT_MISE_TOOLS; do
      _sparklinekit_bootstrap_path="$(mise which "$_sparklinekit_bootstrap_tool" 2>/dev/null || true)"
      if [ -n "$_sparklinekit_bootstrap_path" ]; then
        _sparklinekit_mise_prepend "$(dirname "$_sparklinekit_bootstrap_path")"
      fi
    done
    unset _sparklinekit_bootstrap_tool _sparklinekit_bootstrap_path
  fi

  if ! command -v gleam >/dev/null 2>&1 && [ -n "${HOME:-}" ]; then
    _sparklinekit_mise_prepend "$HOME/.local/share/mise/shims"
  fi

  export PATH
}

sparklinekit_require_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0
  fi

  cat >&2 <<EOF
error: required tool '$1' was not found on PATH.

This repository manages its toolchain (Erlang, Gleam, rebar3, Node)
with mise. To set up the development environment from a fresh
checkout:

    mise install

If mise itself is missing, see https://mise.jdx.dev/getting-started.html.
Alternatively, install '$1' by hand and make sure it is on PATH
before running this command.
EOF
  return 127
}

sparklinekit_mise_bootstrap
