#!/bin/sh

report="./luacov.report.out"

if [[ ! -f "$report" ]]; then
  luacov
fi

summary_line=$(cat $report | grep Missed --line-number | cut -d':' -f1)

report_length=$(cat $report | wc -l)

summary_tail=$(echo "$report_length - $summary_line + 1" | bc)

# tail -n "$summary_tail" "$report" | sed "s!$HOME/.hammerspoon/stackline!!g"
tail -n "$summary_tail" "$report"
