#!usr/bin/env bash
# ================================================
# syshealth.sh - System Health & Log Analysis Toolkit
# Lab 1 - Data Collector
# Author: Your Name
# Date: $(date +%Y-%m-%d)
# ===============================================
# --- Variables and quoting demonstration ---
HOSTNAME=$(hostname)
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
# IMPORTANT: Quoting demo (Python/Java students read this!)
# Without quotes → word-splitting bug (try it!)
# With double quotes → safe (Bash best practice)
echo "Hostname without quotes: $HOSTNAME" # works here but dangerous later
echo "Hostname with quotes: \"$HOSTNAME\"" # always do this
# Add a comment explaining the difference (required for marks):
cat << EOF
# COMMENT FOR GRADER:
# In Python/Java variables expand safely.
# In Bash, unquoted \$VAR splits on spaces/tabs/newlines.
# Always double-quote unless you deliberately want splitting. 
EOF
