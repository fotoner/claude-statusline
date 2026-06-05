#!/usr/bin/env bash
# Claude Code Statusline — pretty 3-line status bar
# stdin: JSON from Claude Code statusline system
# stdout: 3 lines with ANSI 256-color

set -euo pipefail

# ── Color palette (256-color) ─────────────────────────────────
C_CYAN='\033[1;38;5;117m'
C_GREEN='\033[38;5;151m'
C_YELLOW='\033[38;5;222m'
C_BLUE='\033[38;5;153m'
C_MAGENTA='\033[38;5;183m'
C_RED='\033[38;5;210m'
C_PINK='\033[38;5;218m'
C_DIM='\033[2m'
C_BOLD='\033[1m'
C_RESET='\033[0m'

# ── Read JSON from stdin ──────────────────────────────────────
json="$(cat)"

jq_val() { echo "$json" | jq -r "$1 // empty" 2>/dev/null; }

model="$(jq_val '.model.display_name')"
version="$(jq_val '.version')"
effort="$(jq_val '.effort.level')"
session_id="$(jq_val '.session_id')"
workdir="$(jq_val '.workspace.current_dir')"
[ -z "$workdir" ] && workdir="$(jq_val '.cwd')"
used_pct="$(jq_val '.context_window.used_percentage')"
added="$(jq_val '.cost.total_lines_added')"
removed="$(jq_val '.cost.total_lines_removed')"
cost="$(jq_val '.cost.total_cost_usd')"
duration_ms="$(jq_val '.cost.total_duration_ms')"
pr_num="$(jq_val '.pr.number')"
pr_url="$(jq_val '.pr.url')"
pr_state="$(jq_val '.pr.review_state')"
rl_5h="$(jq_val '.rate_limits.five_hour.used_percentage')"
rl_7d="$(jq_val '.rate_limits.seven_day.used_percentage')"

# ── Git status (cached per session) ──────────────────────────
# Status line runs on every assistant message; cache git lookups
# in a session-scoped temp file so we hit git at most once per TTL.
cache_ttl=5
safe_id="${session_id:-nosession}"
safe_id="${safe_id//[^A-Za-z0-9_-]/_}"
cache_file="${TMPDIR:-/tmp}/claude-statusline-git-${safe_id}"

compute_git() {  # -> "<is_git>\t<branch>\t<dirty>"
  local b
  if [ -n "$workdir" ] && git -C "$workdir" --no-optional-locks rev-parse --is-inside-work-tree &>/dev/null; then
    b="$(git -C "$workdir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || echo 'detached')"
    if [ -n "$(git -C "$workdir" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
      printf '1\t%s\t1\n' "$b"
    else
      printf '1\t%s\t0\n' "$b"
    fi
  else
    printf '0\t\t0\n'
  fi
}

get_git_status() {  # sets globals: is_git branch dirty
  is_git=0; branch=""; dirty=0
  local raw="" now="" age="" mtime=""
  now="$(date +%s 2>/dev/null || echo 0)"
  if [ -f "$cache_file" ]; then
    # GNU stat (-c) first, BSD stat (-f) fallback; guard against non-numeric output
    mtime="$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null || echo 0)"
    case "$mtime" in *[!0-9]*|"") mtime=0 ;; esac
    age=$(( now - mtime ))
    [ "$age" -le "$cache_ttl" ] && raw="$(cat "$cache_file" 2>/dev/null || true)"
  fi
  if [ -z "$raw" ]; then
    raw="$(compute_git)"
    printf '%s\n' "$raw" > "$cache_file" 2>/dev/null || true
  fi
  IFS=$'\t' read -r is_git branch dirty <<< "$raw" || true
}

# ── Line 1: Model, Effort & Version ──────────────────────────
line1="${C_CYAN}🤖 ${model:-unknown}${C_RESET}"
[ -n "$effort" ] && line1="${line1}  ${C_YELLOW}⚡${effort}${C_RESET}"
line1="${line1} ${C_DIM}v${version:-?}${C_RESET}"

# ── Line 2: Workspace & Git ──────────────────────────────────
display_dir="${workdir/#$HOME/~}"
line2="${C_BLUE}📁 ${display_dir:-?}${C_RESET}"

get_git_status
if [ "$is_git" = "1" ]; then
  if [ "$dirty" = "1" ]; then
    git_icon="${C_YELLOW}✏️${C_RESET}"
  else
    git_icon="${C_GREEN}✅${C_RESET}"
  fi

  line2="${line2}  ${C_MAGENTA}🌿 ${branch}${C_RESET} ${git_icon}"
fi

# PR badge — only when an open PR exists for the branch.
# pr_label uses OSC 8 so the number is a clickable link to the PR.
if [ -n "$pr_num" ]; then
  if [ -n "$pr_url" ]; then
    pr_label="\033]8;;${pr_url}\a#${pr_num}\033]8;;\a"
  else
    pr_label="#${pr_num}"
  fi
  case "$pr_state" in
    approved)          pr_st=" ${C_GREEN}✓approved${C_RESET}" ;;
    changes_requested) pr_st=" ${C_RED}✗changes${C_RESET}" ;;
    pending)           pr_st=" ${C_YELLOW}…pending${C_RESET}" ;;
    draft)             pr_st=" ${C_DIM}◌draft${C_RESET}" ;;
    *)                 pr_st="" ;;
  esac
  line2="${line2}  ${C_BLUE}🔗 ${pr_label}${C_RESET}${pr_st}"
fi

# ── Line 3: Session Stats ─────────────────────────────────────

# Context bar
bar_width=20
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  pct_int="${used_pct%.*}"
  [ -z "$pct_int" ] && pct_int=0
  filled=$(( pct_int * bar_width / 100 ))
  [ $filled -gt $bar_width ] && filled=$bar_width
  empty=$(( bar_width - filled ))

  if [ "$pct_int" -ge 80 ]; then
    bar_color="$C_RED"
  elif [ "$pct_int" -ge 60 ]; then
    bar_color="$C_YELLOW"
  else
    bar_color="$C_GREEN"
  fi

  bar_fill="$(printf '#%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null || true)"
  bar_empty="$(printf -- '-%.0s' $(seq 1 $empty 2>/dev/null) 2>/dev/null || true)"

  ctx_part="${bar_color}🧠 [${bar_fill}${bar_empty}] ${pct_int}%${C_RESET}"
else
  ctx_part="${C_DIM}🧠 [--------------------] ?%${C_RESET}"
fi

# Lines changed
lines_part="${C_PINK}📝 +${added:-0} -${removed:-0}${C_RESET}"

# Cost
cost_fmt="$(printf '%.2f' "${cost:-0}" 2>/dev/null || echo '0.00')"
cost_part="${C_YELLOW}💰 \$${cost_fmt}${C_RESET}"

# Duration
dur_s=$(( ${duration_ms:-0} / 1000 ))
if [ $dur_s -ge 3600 ]; then
  h=$(( dur_s / 3600 ))
  m=$(( (dur_s % 3600) / 60 ))
  time_str="${h}h ${m}m"
elif [ $dur_s -ge 60 ]; then
  m=$(( dur_s / 60 ))
  s=$(( dur_s % 60 ))
  time_str="${m}m ${s}s"
else
  time_str="${dur_s}s"
fi
time_part="${C_GREEN}⏱️ ${time_str}${C_RESET}"

# Rate limits (Claude.ai Pro/Max only; absent otherwise)
rl_part=""
if [ -n "$rl_5h" ] || [ -n "$rl_7d" ]; then
  rl_seg=""
  [ -n "$rl_5h" ] && rl_seg="${rl_5h%.*}%"
  [ -n "$rl_7d" ] && rl_seg="${rl_seg:+$rl_seg · }${rl_7d%.*}%"
  rl_part="  ${C_BLUE}📊 ${rl_seg}${C_RESET}"
fi

line3="${ctx_part}  ${lines_part}  ${cost_part}  ${time_part}${rl_part}"

# ── Output ────────────────────────────────────────────────────
printf "%b\n%b\n%b\n" "$line1" "$line2" "$line3"
