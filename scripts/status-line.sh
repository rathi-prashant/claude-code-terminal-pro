#!/bin/bash

# Claude Code Status Line Script - Gruvbox Dark Theme
# Format: [Model Name] | [Progress Bar] pct | tokens | $cost | [directory] | [git branch] | version

# Read JSON input
input=$(cat)

# Extract values
model_name=$(echo "$input" | jq -r '.model.display_name')
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
version=$(echo "$input" | jq -r '.version // empty')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Gruvbox Dark color palette
MODEL_COLOR="\033[38;2;86;182;194m"       # Model name - #56B6C2 (bright teal)
BRACKET_COLOR="\033[38;2;102;92;84m"      # Progress bar brackets/separators - Gruvbox gray #665C54
EMPTY_BAR_COLOR="\033[38;2;50;48;47m"     # Empty bar segments - Near-background #32302F
FILLED_BAR_COLOR="\033[38;2;142;192;124m" # Filled bar segments - Gruvbox Aqua #8EC07C
PERCENTAGE_COLOR="\033[38;2;251;241;199m" # Percentage number - Bright foreground #FBF1C7 (emphasized)
TOKEN_COLOR="\033[38;2;224;175;104m"      # Token budget - #E0AF68
GIT_COLOR="\033[38;2;143;175;209m"        # Git branch - #8FAFD1
DIR_COLOR="\033[38;2;152;195;121m"        # Directory - #98C379
COST_COLOR="\033[38;2;211;134;155m"       # Cost - #D3869B (soft pink)
VERSION_COLOR="\033[38;2;102;92;84m"      # Version - #665C54 (dim gray)
RESET="\033[0m"

# Calculate real token usage from used_percentage (includes thinking/reasoning tokens)
# used_percentage is the source of truth from Claude Code - it accounts for all token
# types including thinking tokens, cache tokens, etc. Using total_input_tokens +
# total_output_tokens would undercount since thinking tokens are not reported there.
if [ "$used_percentage" != "null" ] && [ "$used_percentage" != "0" ]; then
    tokens_used=$(echo "scale=0; $used_percentage * $context_window_size / 100" | bc)
else
    tokens_used=0
fi

# Build status line
status_line=""

# 1. Model name
[ -n "$model_name" ] && status_line+=$(printf "${MODEL_COLOR}✦ %s${RESET}" "$model_name")

# 2. Progress bar for token usage (20-segment, each = 5%)
if [ -n "$used_percentage" ] && [ "$used_percentage" != "null" ]; then
    bar="${BRACKET_COLOR}[${RESET}"
    for segment in {1..20}; do
        threshold=$(echo "scale=2; $segment * 5" | bc)
        if (( $(echo "$used_percentage >= $threshold" | bc -l) )); then
            bar+="${FILLED_BAR_COLOR}■${RESET}"
        else
            bar+="${EMPTY_BAR_COLOR}□${RESET}"
        fi
    done
    bar+="${BRACKET_COLOR}]${RESET}"
    pct=$(printf "%.0f" "$used_percentage")
    status_line+=$(printf " | %s ${PERCENTAGE_COLOR}%s%%${RESET}" "$bar" "$pct")
fi

# 3. Token count (granular, derived from used_percentage)
if [ "$tokens_used" -gt 0 ]; then
    ctx_k=$(echo "scale=0; $context_window_size / 1000" | bc)
    tok_k=$(echo "scale=0; $tokens_used / 1000" | bc)
    status_line+=$(printf " | ${TOKEN_COLOR}↯ %sk/%sk${RESET}" "$tok_k" "$ctx_k")
fi

# 4. Cost (estimated API equivalent)
if [ "$total_cost" != "0" ] && [ "$total_cost" != "null" ]; then
    cost_fmt=$(printf "%.2f" "$total_cost")
    status_line+=$(printf " | ${COST_COLOR}\$ %s USD${RESET}" "$cost_fmt")
fi

# 5. Directory
if [ -n "$cwd" ]; then
    dir_name=$(basename "$cwd")
    status_line+=$(printf " | ${DIR_COLOR}◆ %s${RESET}" "$dir_name")
fi

# 6. Git branch
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    cd "$cwd" 2>/dev/null
    if git rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(git --no-optional-locks branch --show-current 2>/dev/null)
        [ -n "$branch" ] && status_line+=$(printf " | ${GIT_COLOR}⎇ %s${RESET}" "$branch")
    fi
fi

# 7. Version
[ -n "$version" ] && status_line+=$(printf " | ${VERSION_COLOR}v%s${RESET}" "$version")

# Output the status line
echo -e "$status_line"
