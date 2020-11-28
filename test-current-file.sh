#!/bin/sh

# DEPENDENCIES -----------------------------------------------------------------
# kitty:  https://github.com/kovidgoyal/kitty
# fd:     https://github.com/sharkdp/fd
# jq:     https://github.com/stedolan/jq
# busted: https://github.com/Olivine-Labs/busted

# USAGE ------------------------------------------------------------------------
# Finds the active vim buffer via Kitty title, and runs busted tests for that file.
# Works with source files *and* test files
# Use with `entr` to automatically run the current file's tests on save

# EXAMPLE
# fd -e lua | entr -c ./test-current-file.sh

active_kitty_win() {
  jq_filter_active_window='map(select(.is_focused==true))[]
                              | .tabs[]
                              | select(.is_focused==true)
                              | .windows[]
                              | select(.is_focused==true)'

  active_window=$(kitty @ ls | jq -r "$jq_filter_active_window")
  printf '%s' "$active_window"
}

active_buffer_filename="$(active_kitty_win \
  | jq '.title' \
  | cut -d ' ' -f1 \
  | cut -d '"' -f2)"

current_file="$(fd $active_buffer_filename | head -n1 | xargs -I{} basename "{}" | cut -d '.' -f1)"

current_test_file="$(fd $current_file ./spec)"

busted "$current_test_file"
