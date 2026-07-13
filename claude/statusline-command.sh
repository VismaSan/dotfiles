#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // "Unknown Model"')
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')
worktree_branch=$(echo "$input" | jq -r '.worktree.branch // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cache_creation=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
current_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
ORANGE='\033[38;5;208m'
RED='\033[31m'
RESET='\033[0m'

# cwd: show basename of directory
dir_display=$(basename "$cwd")

# git info: branch + status (staged/modified counts)
git_branch=""
git_status=""
if cd "$cwd" 2>/dev/null && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -z "$git_branch" ] && git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  staged=$(git -C "$cwd" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
  modified=$(git -C "$cwd" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
  untracked=$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  parts=""
  [ "$staged" -gt 0 ]    && parts="${parts}$(printf "${GREEN}+${staged}${RESET} ")"
  [ "$modified" -gt 0 ]  && parts="${parts}$(printf "${YELLOW}~${modified}${RESET} ")"
  [ "$untracked" -gt 0 ] && parts="${parts}$(printf "?${untracked} ")"
  git_status=$(printf "%s" "$parts" | sed 's/ $//')
fi

# tokens used: sum of total input + output tokens
tokens_total=$(( total_input + total_output ))
if [ "$tokens_total" -ge 1000000 ]; then
  tokens_str=$(awk "BEGIN { printf \"%.1fM\", $tokens_total / 1000000 }")
elif [ "$tokens_total" -ge 1000 ]; then
  tokens_str=$(awk "BEGIN { printf \"%.1fk\", $tokens_total / 1000 }")
else
  tokens_str="${tokens_total}"
fi

# used percentage
if [ -n "$used" ]; then
  used_display=$(printf "%.0f" "$used")
  used_str="${used_display}%"
else
  used_str="-%"
fi

# info color: green <41%, orange 41-55%, red >55%
if [ -n "$used" ] && awk "BEGIN { exit !($used < 41) }"; then
  info_color="$GREEN"
elif [ -n "$used" ] && awk "BEGIN { exit !($used <= 55) }"; then
  info_color="$ORANGE"
else
  info_color="$RED"
fi

# cache hit rate: cache_read / (cache_read + cache_creation + input_tokens) * 100
total_input_tokens=$(( cache_read + cache_creation + current_input ))
cache_hit_str="-"
if [ "$total_input_tokens" -gt 0 ] && [ "$cache_read" -gt 0 ]; then
  cache_hit_str=$(awk "BEGIN { printf \"%.0f%%\", ($cache_read / $total_input_tokens) * 100 }")
elif [ "$total_input_tokens" -gt 0 ]; then
  cache_hit_str="0%"
fi

# Build worktree section: shown right after the git branch when this session
# is running inside a worktree (Claude Code populates .worktree.* on stdin).
worktree_section=""
if [ -n "$worktree_name" ]; then
  if [ -n "$worktree_branch" ]; then
    worktree_section=$(printf " ${ORANGE}[wt:%s@%s]${RESET}" "$worktree_name" "$worktree_branch")
  else
    worktree_section=$(printf " ${ORANGE}[wt:%s]${RESET}" "$worktree_name")
  fi
fi

# Build git section
if [ -n "$git_branch" ]; then
  if [ -n "$git_status" ]; then
    git_section="${git_branch}${worktree_section} ${git_status}"
  else
    git_section="${git_branch}${worktree_section}"
  fi
  printf "${CYAN}%s${RESET} %s | %s ${info_color}(%s, %s)${RESET} | cache: %s\n" \
    "$dir_display" "$git_section" "$model" "$tokens_str" "$used_str" "$cache_hit_str"
else
  printf "${CYAN}%s${RESET}%s | %s ${info_color}(%s, %s)${RESET} | cache: %s\n" \
    "$dir_display" "$worktree_section" "$model" "$tokens_str" "$used_str" "$cache_hit_str"
fi
