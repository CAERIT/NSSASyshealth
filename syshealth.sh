#!/usr/bin/env bash
# ================================================
# syshealth.sh - System Health & Log Analysis Toolkit
# Lab 3 - Refactoring into Functions
# Author: Calvin Eisenhofer
# Date: $(date +%Y-%m-%d)
# ===============================================

# --- Variables and quoting demonstration ---
HOSTNAME=$(hostname)
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
# --- Thresholds (change these values to test alert behavior) ---
CPU_THRESHOLD=75
MEM_THRESHOLD=85
DISK_THRESHOLD=85


print_status() {
local status="$1"
local message="$2"
	if [ "$status" = "OK" ]; then
		echo -e "\e[32m OK: $message\e[0m"
	else
		echo -e "\e[31m ALERT: $message\e[0m"
	fi
}

# IMPORTANT: Quoting demo (Python/Java students read this!)
# Without quotes → word-splitting bug (try it!)
# With double quotes → safe (Bash best practice)
#echo "Hostname without quotes: $HOSTNAME" # works here but dangerous later
#echo "Hostname with quotes: \"$HOSTNAME\"" # always do this
# Add a comment explaining the difference (required for marks):
#cat << EOF
# COMMENT FOR GRADER:
# In Python/Java variables expand safely.
# In Bash, unquoted \$VAR splits on spaces/tabs/newlines.
# Always double-quote unless you deliberately want splitting. 
#EOF

# --- System metrics collection ---
UPTIME=$(uptime -p)
DISK_USAGE=$(df -h / | tail -1)
MEMORY_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
PROCESS_COUNT=$(ps -e | wc -l)

# --- Parse numeric percentages for threshold comparison (Rocky Linux 9 compatible) ---
# Disk usage percentage for root filesystem (strip the % sign)
DISK_PCT=$(df / | tail -1 | awk '{gsub("%",""); print $5}')


# Memory usage percentage (used / total * 100), rounded to integer
MEM_PCT=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
# CPU usage percentage (100 - idle). The top -bn1 method is a common one-liner
# that works on Rocky Linux 9. Note: This is a brief snapshot; production tools
# often average over time or use /proc/stat directly.
CPU_PCT=$(top -bn1 | grep '^%Cpu' | awk '{print 100 - $8}' | cut -d. -f1)


# --- Health checks with conditionals and color-coded output ---
print_status "CHECK" "Running system health analysis..."
HEALTH_STATUS=0 # 0 = healthy (no alerts). Will be set to 1 if any check fails.


check_disk_usage() {
	local mount="$1"
	local pct threshold
	threshold="$DISK_THRESHOLD"
	if ! mountpoint -q "$mount" 2>/dev/null && [ "$mount" != "/" ]; then
		print_status "OK" "Mount point $mount does not exist on this system"
		return 0
	fi
	pct=$(df "$mount" | tail -1 | awk '{gsub("%",""); print $5}')
	if (( pct > threshold )); then
		print_status "ALERT" "Disk usage on $mount is ${pct}% (threshold ${threshold}%)"
	return 1
	else
		print_status "OK" "Disk usage on $mount is ${pct}%"
	return 0
	fi
}








# Disk check for root filesystem
if (( DISK_PCT > DISK_THRESHOLD )); then
	print_status "ALERT" "Disk usage on / is ${DISK_PCT}% (threshold ${DISK_THRESHOLD}%)"
	HEALTH_STATUS=1
else
	print_status "OK" "Disk usage on / is ${DISK_PCT}%"
fi
# --- Loop over multiple mount points (more realistic monitoring) ---
for mount in / /home /var; do
	if mountpoint -q "$mount" 2>/dev/null || [ "$mount" = "/" ]; then 
		PCT=$(df "$mount" | tail -1 | awk '{gsub("%",""); print $5}')
	if (( PCT > DISK_THRESHOLD )); then
		print_status "ALERT" "Disk usage on $mount is ${PCT}% (threshold${DISK_THRESHOLD}%)"
		HEALTH_STATUS=1
	else
		print_status "OK" "Disk usage on $mount is ${PCT}%"
	fi
	else
		print_status "OK" "Mount point $mount does not exist or is not a mountpoint on this system"
	fi
done

check_memory_usage() {
	local pct threshold
	threshold="$MEM_THRESHOLD"
	pct=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')
	if (( pct > threshold )); then
		print_status "ALERT" "Memory usage is ${pct}% (threshold ${threshold}%)"
		return 1
	else
		print_status "OK" "Memory usage is ${pct}%"
	return 0
	fi
}



check_cpu_usage() {
	local pct threshold
	threshold="$CPU_THRESHOLD"
	pct=$(top -bn1 | grep '^%Cpu' | awk '{print 100 - $8}' | cut -d. -f1)
	if (( pct > threshold )); then
		print_status "ALERT" "CPU usage is ${pct}% (threshold ${threshold}%)"
		return 1
	else
		print_status "OK" "CPU usage is ${pct}%"
		return 0
	fi
}


run_health_checks() {
	local overall_status=0
	print_status "CHECK" "Running system health analysis..."
	# Disk checks via loop (replaces the inline for-loop from Lab 2)
	for mount in / /home /var; do
		if ! check_disk_usage "$mount"; then
			overall_status=1
		fi
	done
	
	# Memory check
	if ! check_memory_usage; then
	overall_status=1
	fi
	
	# CPU check
	if ! check_cpu_usage; then
		overall_status=1
	fi
	
	# Store result for generate_report / exit
	HEALTH_STATUS="$overall_status"
	return "$overall_status"
}


parse_arguments() {
	OUTPUT_FILE="${1:-}" # if $1 is given, use it as output file; otherwise empty
}


generate_report() {
	# Re-collect the human-readable metrics (same as Lab 1)
	local CURRENT_DATE HOSTNAME UPTIME DISK_USAGE MEMORY_USAGE PROCESS_COUNT
	CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
	HOSTNAME=$(hostname)
	UPTIME=$(uptime -p)
	DISK_USAGE=$(df -h / | tail -1)
	MEMORY_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
	PROCESS_COUNT=$(ps -e | wc -l)
	printf "========================================\n"
	printf "System Health Report - %s\n" "$CURRENT_DATE"
	printf "Hostname : %s\n" "$HOSTNAME"
	printf "Uptime : %s\n" "$UPTIME"
	printf "Disk / : %s\n" "$DISK_USAGE"
	printf "Memory used : %s\n" "$MEMORY_USAGE"
	printf "Total processes : %s\n" "$PROCESS_COUNT"
	printf "Health status : %s\n" "$([ "${HEALTH_STATUS:-0}" -eq 0 ] && echo "HEALTHY" || echo "UNHEALTHY - see alerts above")"
	printf "========================================\n"
	printf "Health status : %s\n" "$([ "${HEALTH_STATUS:-0}" -eq 0 ] && echo "HEALTHY" || echo "UNHEALTHY - see alerts above")"
printf "========================================\n"
# --- NEW: Log Analysis Summary (integrated into every report) ---
printf "\n========================================\n"
printf "LOG ANALYSIS SUMMARY\n"
printf "========================================\n"
analyze_logs # uses default /var/log/messages
}



# Memory check
#if (( MEM_PCT > MEM_THRESHOLD )); then
#	print_status "ALERT" "Memory usage is ${MEM_PCT}% (threshold ${MEM_THRESHOLD}%)"
#	HEALTH_STATUS=1
#else
#	print_status "OK" "Memory usage is ${MEM_PCT}%"
#fi
## CPU check
#if (( CPU_PCT > CPU_THRESHOLD )); then
#	print_status "ALERT" "CPU usage is ${CPU_PCT}% (threshold ${CPU_THRESHOLD}%)"
#	HEALTH_STATUS=1
#else
#	print_status "OK" "CPU usage is ${CPU_PCT}%"
#fi
#


# --- Final report and exit code handling ---
OUTPUT_FILE="${1:-}"
print_report() {

	printf "========================================\n"
	printf "System Health Report - %s\n" "$CURRENT_DATE"
	printf "Hostname : %s\n" "$HOSTNAME"
	printf "Uptime : %s\n" "$UPTIME"
	printf "Disk / : %s\n" "$DISK_USAGE"
	printf "Memory used : %s\n" "$MEMORY_USAGE"
	printf "Total processes : %s\n" "$PROCESS_COUNT"
	printf "Health status : %s\n" "$([ "$HEALTH_STATUS" -eq 0 ] && echo "HEALTHY" || echo "UNHEALTHY - see alerts above")"
	printf "========================================\n"
}
if [ -n "$OUTPUT_FILE" ]; then
	print_report > "$OUTPUT_FILE"
	echo "Report written to $OUTPUT_FILE (alerts were printed to terminal)"
else
	print_report
fi
# Exit with 0 (healthy) or 1 (alerts triggered). This enables scripting / cron usage.
exit "${HEALTH_STATUS:-0}"


analyze_logs() {
local log_file="${1:-/var/log/messages}" # default to Rocky Linux 9 main log
local errors=0
local warnings=0
local failed_logins=0
local top_issues
# Graceful handling if log file is missing or unreadable
if [ ! -r "$log_file" ]; then
printf "\nLog Analysis Summary (%s):\n" "$(basename "$log_file")"
printf " Log file not readable or does not exist on this system.\n"
printf " (This is normal in some containers or minimal installs.)\n"
return 0
fi
# Count issues using extended regex (case-insensitive where useful)
errors=$(grep -E -i 'ERROR|Error|error' "$log_file" 2>/dev/null | wc -l)
warnings=$(grep -E -i 'WARNING|Warning|warning' "$log_file" 2>/dev/null |wc -l)
failed_logins=$(grep -E -i 'Failed password|authentication failure|Failed login' "$log_file" 2>/dev/null | wc -l)
# Top 5 most common error/warning messages (cleaned with sed)
printf "\nTop 5 recurring issues:\n"
grep -E -i 'ERROR|Error|error|WARNING|Warning|warning|Failed password|authentication failure' "$log_file" 2>/dev/null \
| sed 's/.*\]: //' \
| sort \
| uniq -c \
| sort -nr \
| head -5
# Summary section
printf "\nLog Analysis Summary (%s):\n" "$(basename "$log_file")"
printf " Errors : %d\n" "$errors"
printf " Warnings : %d\n" "$warnings"
printf " Failed logins : %d\n" "$failed_logins"
}


# Temporary test stub (remove before final submission if not needed)
#if [ "$1" = "--test-logs" ]; then
#analyze_logs "/var/log/secure" # or any test log you create
#exit 0
#fi



main() {
	parse_arguments "$@"
	# Run all health checks (prints colored alerts to terminal)
	run_health_checks
	# Generate the structured report (to screen or file)
	if [ -n "$OUTPUT_FILE" ]; then
		generate_report > "$OUTPUT_FILE"
		echo "Report written to $OUTPUT_FILE"
	else
		generate_report
	fi
	# Exit with the aggregated health status from run_health_checks
	exit "${HEALTH_STATUS:-0}"
	}


main
