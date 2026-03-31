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
workdir="$(jq_val '.workspace.current_dir')"
[ -z "$workdir" ] && workdir="$(jq_val '.cwd')"
used_pct="$(jq_val '.context_window.used_percentage')"
ctx_size="$(jq_val '.context_window.context_window_size')"
input_tok="$(jq_val '.context_window.total_input_tokens')"
output_tok="$(jq_val '.context_window.total_output_tokens')"
added="$(jq_val '.cost.total_lines_added')"
removed="$(jq_val '.cost.total_lines_removed')"
cost="$(jq_val '.cost.total_cost_usd')"
duration_ms="$(jq_val '.cost.total_duration_ms')"

# ── Line 1: Model & Version ──────────────────────────────────
line1="${C_CYAN}🤖 ${model:-unknown}${C_RESET} ${C_DIM}v${version:-?}${C_RESET}"

# ── Line 2: Workspace & Git ──────────────────────────────────
display_dir="${workdir/#$HOME/\~}"
line2="${C_BLUE}📁 ${display_dir:-?}${C_RESET}"

if [ -n "$workdir" ] && git -C "$workdir" --no-optional-locks rev-parse --is-inside-work-tree &>/dev/null; then
  branch="$(git -C "$workdir" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || echo 'detached')"

  dirty=false
  [ -n "$(git -C "$workdir" --no-optional-locks diff --shortstat 2>/dev/null)" ] && dirty=true
  [ -n "$(git -C "$workdir" --no-optional-locks diff --cached --shortstat 2>/dev/null)" ] && dirty=true
  [ -n "$(git -C "$workdir" --no-optional-locks ls-files --others --exclude-standard 2>/dev/null)" ] && dirty=true

  if $dirty; then
    git_icon="${C_YELLOW}✏️${C_RESET}"
  else
    git_icon="${C_GREEN}✅${C_RESET}"
  fi

  line2="${line2}  ${C_MAGENTA}🌿 ${branch}${C_RESET} ${git_icon}"
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

  remaining_k=0
  if [ -n "$ctx_size" ] && [ -n "$input_tok" ] && [ -n "$output_tok" ]; then
    remaining_k=$(( (ctx_size - input_tok - output_tok) / 1000 ))
    [ $remaining_k -lt 0 ] && remaining_k=0
  fi

  ctx_part="${bar_color}🧠 [${bar_fill}${bar_empty}] ${pct_int}%${C_RESET} ${C_DIM}(${remaining_k}k left)${C_RESET}"
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

line3="${ctx_part}  ${lines_part}  ${cost_part}  ${time_part}"

# ── Output ────────────────────────────────────────────────────
printf "%b\n%b\n%b\n" "$line1" "$line2" "$line3"
