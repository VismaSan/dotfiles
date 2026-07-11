#!/bin/sh
# Claude Code status line
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip optional locks for safety)
branch_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" -c gc.auto=0 symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" -c gc.auto=0 rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    branch_info=" [${branch}]"
  fi
fi

# Context used percentage with color: dimmed green below 45, dimmed orange at 45+
ctx_colored=""
if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used")
  if [ "$pct" -lt 45 ]; then
    # Dimmed green
    ctx_colored="\033[2;32m (${pct}%)\033[0m"
  else
    # Dimmed orange (color 214 is a standard orange in 256-color)
    ctx_colored="\033[2;38;5;214m (${pct}%)\033[0m"
  fi
fi

# Build a usage bar: filled blocks out of 10 total
# arg1: used percentage (0-100), arg2: label
make_bar() {
  _pct="$1"
  _label="$2"
  _filled=$(( (_pct * 10 + 50) / 100 ))
  [ "$_filled" -gt 10 ] && _filled=10
  _empty=$(( 10 - _filled ))
  _bar=""
  _i=0
  while [ "$_i" -lt "$_filled" ]; do
    _bar="${_bar}█"
    _i=$(( _i + 1 ))
  done
  _i=0
  while [ "$_i" -lt "$_empty" ]; do
    _bar="${_bar}░"
    _i=$(( _i + 1 ))
  done
  # Color: green below 70%, orange 70-89%, red 90%+
  if [ "$_pct" -lt 70 ]; then
    printf "\033[2;32m%s %s %d%%\033[0m" "$_label" "$_bar" "$_pct"
  elif [ "$_pct" -lt 90 ]; then
    printf "\033[2;38;5;214m%s %s %d%%\033[0m" "$_label" "$_bar" "$_pct"
  else
    printf "\033[2;31m%s %s %d%%\033[0m" "$_label" "$_bar" "$_pct"
  fi
}

# Row 1: cwd [branch] | model (context%)
printf "\033[34m%s\033[0m\033[2m%s\033[0m | %s%b" \
  "$short_cwd" "$branch_info" "$model" "$ctx_colored"

# Row 2: rate limit bars (only shown when data is available)
row2=""
if [ -n "$five_pct" ]; then
  five_int=$(printf '%.0f' "$five_pct")
  bar5=$(make_bar "$five_int" "5h")
  row2="$bar5"
fi
if [ -n "$week_pct" ]; then
  week_int=$(printf '%.0f' "$week_pct")
  bar7=$(make_bar "$week_int" "7d")
  if [ -n "$row2" ]; then
    row2="${row2}  ${bar7}"
  else
    row2="$bar7"
  fi
fi
if [ -n "$row2" ]; then
  printf "\n%b" "$row2"
fi
