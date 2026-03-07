#!/usr/bin/env bash
# ===================================================================
# compare_page_faults.sh
# -------------------------------------------------------------------
# Runs the demand-paging demo three times (seq, random, stride) and
# compares the page fault counts side-by-side using vmstat logs.
#
# Usage:
#   chmod +x compare_page_faults.sh
#   ./compare_page_faults.sh [size_MB]
#
# Author: Self-Learning Practice – Operating Systems (B24CS2T04)
# ===================================================================

SIZE_MB=${1:-512}
DEMO="./demand_paging_demo"
RESULT_FILE="page_fault_comparison.txt"

# ---- compile if needed -------------------------------------------
if [ ! -x "$DEMO" ]; then
    echo "[*] Compiling demand_paging_demo.c ..."
    gcc -O0 -o demand_paging_demo demand_paging_demo.c
    if [ $? -ne 0 ]; then
        echo "[!] Compilation failed."
        exit 1
    fi
fi

echo "================================================================"
echo "  Page-Fault Comparison Across Access Patterns"
echo "  Allocation : ${SIZE_MB} MB"
echo "================================================================"
echo ""

# Temp files
SEQ_LOG=$(mktemp)
RND_LOG=$(mktemp)
STR_LOG=$(mktemp)

# ---- Run each pattern --------------------------------------------
for PATTERN in seq random stride; do
    echo "---------- Running pattern: $PATTERN ----------"

    # Capture vmstat during the run (1-second intervals)
    VLOG="vmstat_run_${PATTERN}.log"
    vmstat 1 > "$VLOG" 2>&1 &
    VPID=$!

    case "$PATTERN" in
        seq)    $DEMO "$SIZE_MB" seq    > "$SEQ_LOG" 2>&1 ;;
        random) $DEMO "$SIZE_MB" random > "$RND_LOG" 2>&1 ;;
        stride) $DEMO "$SIZE_MB" stride > "$STR_LOG" 2>&1 ;;
    esac

    kill "$VPID" 2>/dev/null; wait "$VPID" 2>/dev/null
    echo "  vmstat log saved to $VLOG"
    echo ""

    # Brief pause between runs so system settles
    sleep 3
done

# ---- Extract key numbers -----------------------------------------
extract() {
    # $1 = log file
    # Grab "minor=NNN  major=NNN" from Phase 2 line
    local minor major time
    minor=$(grep "Page faults during access" "$1" | head -1 | sed 's/.*minor=\([0-9]*\).*/\1/')
    major=$(grep "Page faults during access" "$1" | head -1 | sed 's/.*major=\([0-9]*\).*/\1/')
    time=$(grep "Time elapsed" "$1" | head -1 | sed 's/.*: *\([0-9.]*\).*/\1/')
    echo "$minor $major $time"
}

read SEQ_MIN SEQ_MAJ SEQ_T  <<< $(extract "$SEQ_LOG")
read RND_MIN RND_MAJ RND_T  <<< $(extract "$RND_LOG")
read STR_MIN STR_MAJ STR_T  <<< $(extract "$STR_LOG")

# ---- Print comparison table --------------------------------------
{
    echo "================================================================"
    echo "  PAGE FAULT COMPARISON  –  ${SIZE_MB} MB allocation"
    echo "  Date : $(date)"
    echo "================================================================"
    echo ""
    printf "%-12s %12s %12s %12s\n" "Pattern" "Minor Faults" "Major Faults" "Time (s)"
    printf "%-12s %12s %12s %12s\n" "----------" "------------" "------------" "--------"
    printf "%-12s %12s %12s %12s\n" "Sequential"  "$SEQ_MIN"  "$SEQ_MAJ"  "$SEQ_T"
    printf "%-12s %12s %12s %12s\n" "Random"      "$RND_MIN"  "$RND_MAJ"  "$RND_T"
    printf "%-12s %12s %12s %12s\n" "Stride-64"   "$STR_MIN"  "$STR_MAJ"  "$STR_T"
    echo ""
    echo "================================================================"
    echo "Observations:"
    echo "  1. Minor faults should be identical across patterns (~total pages)"
    echo "     because each pattern touches every page exactly once (the random"
    echo "     pattern uses a Fisher-Yates shuffle to ensure this)."
    echo "  2. Random access is typically SLOWER due to poor TLB locality"
    echo "     and cache misses, even though the fault count is similar."
    echo "  3. Major faults appear only if the system runs low on RAM"
    echo "     and has to swap; increase SIZE_MB to trigger this."
    echo "  4. Re-access (Phase 3) causes ~0 faults because pages are"
    echo "     already resident in physical memory."
    echo "================================================================"
} | tee "$RESULT_FILE"

# Cleanup
rm -f "$SEQ_LOG" "$RND_LOG" "$STR_LOG"

echo ""
echo "[Done] Comparison saved to $RESULT_FILE"
