#!/usr/bin/env bash
# Print count and list of calendar events (meetings) for today.
# Used by OpenClaw 8 AM cron (meetings-today-8am) to send to WhatsApp.
# Requires: macOS Calendar.app, osascript (built-in).
# First run: System Settings may prompt to allow Terminal/OpenClaw to access Calendar.
set -euo pipefail

osascript <<'APPLESCRIPT'
set todayStart to (current date)
set hours of todayStart to 0
set minutes of todayStart to 0
set seconds of todayStart to 0
set todayEnd to todayStart + (24 * 60 * 60)

set output to ""
set eventCount to 0

tell application "Calendar"
    repeat with cal in (every calendar)
        try
            set calEvents to (every event of cal whose start date ≥ todayStart and start date < todayEnd)
            repeat with e in calEvents
                set eventCount to eventCount + 1
                set summary to summary of e
                set startTime to start date of e
                set endTime to end date of e
                set output to output & (time string of startTime) & "–" & (time string of endTime) & " " & summary & linefeed
            end repeat
        end try
    end repeat
end tell

if eventCount is 0 then
    return "You have 0 meetings today."
else
    return "You have " & eventCount & " meeting(s) today:" & linefeed & linefeed & output
end if
APPLESCRIPT
