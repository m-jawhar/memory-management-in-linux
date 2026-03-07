#!/usr/bin/env bash
# ===================================================================
# vmstat_monitor.sh
# -------------------------------------------------------------------
# Captures vmstat output before, during, and after running the
# demand-paging demo, then summarises page-fault statistics.
#
# Usage:
#   chmod +x vmstat_monitor.sh
#   ./vmstat_monitor.sh [size_MB] [pattern]
#
#   size_MB  : memory to allocate in MB (default: 512)
#   pattern  : seq | random | stride   (default: seq)
#
# Outputs:
#   vmstat_before_<pattern>.log   – baseline (5 seconds)
#   vmstat_during_<pattern>.log   – while demo is running
#   vmstat_after_<pattern>.log    – cool-down (5 seconds)
#   vmstat_summary_<pattern>.txt  – human-readable summary
#
# Author: Self-Learning Practice – Operating Systems (B24CS2T04)
# ===================================================================

SIZE_MB=${1:-512}
PATTERN=${2:-seq}
DEMO="./demand_paging_demo"
INTERVAL=1                       # vmstat sampling interval (seconds)

LOG_BEFORE="vmstat_before_${PATTERN}.log"
LOG_DURING="vmstat_during_${PATTERN}.log"
LOG_AFTER="vmstat_after_${PATTERN}.log"
SUMMARY="vmstat_summary_${PATTERN}.txt"

# ---- check prerequisites ----------------------------------------
if [ ! -x "$DEMO" ]; then
    echo "[*] Compiling demand_paging_demo.c ..."
    gcc -O0 -o demand_paging_demo demand_paging_demo.c
    if [ $? -ne 0 ]; then
        echo "[!] Compilation failed."
        exit 1
    fi
fi

echo "================================================================"
echo "  vmstat Page-Fault Monitor"
echo "  Allocation : ${SIZE_MB} MB    Pattern : ${PATTERN}"
echo "================================================================"

# ---- Phase A : baseline vmstat (5 s) -----------------------------
echo "[A] Capturing baseline vmstat for 5 seconds ..."
vmstat "$INTERVAL" 6 > "$LOG_BEFORE" 2>&1 &
VMSTAT_PID=$!
sleep 6
wait "$VMSTAT_PID" 2>/dev/null

# ---- Phase B : run demo with vmstat in background ----------------
echo "[B] Starting demand_paging_demo (${SIZE_MB} MB, ${PATTERN}) with vmstat ..."
vmstat "$INTERVAL" > "$LOG_DURING" 2>&1 &
VMSTAT_PID=$!

# Run the actual demo
$DEMO "$SIZE_MB" "$PATTERN"
DEMO_EXIT=$?

# Stop vmstat
kill "$VMSTAT_PID" 2>/dev/null
wait "$VMSTAT_PID" 2>/dev/null

if [ $DEMO_EXIT -ne 0 ]; then
    echo "[!] Demo exited with code $DEMO_EXIT"
fi

# ---- Phase C : cool-down vmstat (5 s) ----------------------------
echo "[C] Capturing cool-down vmstat for 5 seconds ..."
vmstat "$INTERVAL" 6 > "$LOG_AFTER" 2>&1 &
VMSTAT_PID=$!
sleep 6
wait "$VMSTAT_PID" 2>/dev/null

# ---- Summary -----------------------------------------------------
echo ""
echo "================================================================"
echo "  Results written to:  $LOG_BEFORE"
echo "                       $LOG_DURING"
echo "                       $LOG_AFTER"
echo "================================================================"

{
    echo "============================================================"
    echo "  vmstat Page-Fault Summary"
    echo "  Pattern  : $PATTERN"
    echo "  Size     : ${SIZE_MB} MB"
    echo "  Date     : $(date)"
    echo "============================================================"
    echo ""
    echo "--- BASELINE (before demo) ---"
    cat "$LOG_BEFORE"
    echo ""
    echo "--- DURING DEMO ---"
    cat "$LOG_DURING"
    echo ""
    echo "--- AFTER DEMO (cool-down) ---"
    cat "$LOG_AFTER"
    echo ""
    echo "============================================================"
    echo "Key vmstat columns:"
    echo "  r   = processes waiting for run time"
    echo "  b   = processes in uninterruptible sleep"
    echo "  si  = swap in  (KB/s)  – pages read FROM swap (major faults)"
    echo "  so  = swap out (KB/s)  – pages written TO swap"
    echo "  bi  = blocks in  (from disk)"
    echo "  bo  = blocks out (to disk)"
    echo "  in  = interrupts per second"
    echo "  cs  = context switches per second"
    echo "============================================================"
} > "$SUMMARY"

echo ""
cat "$SUMMARY"
echo ""
echo "[Done] See $SUMMARY for the full report."
