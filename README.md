# Memory Management in Linux

**Course:** B24CS2T04 — Operating Systems<br>
**Institution:** Mar Athanasius College of Engineering, Kothamangalam<br>
**Topic 5:** Memory Management in Linux (CO 4 — Apply level)

**Video Class:** [Watch in YouTube](https://youtu.be/U3UWHLdP--w?si=fjuM7m7QE2b-jtnC)

---

## Overview

This project contains a **video class** and an accompanying **report** on memory management in Linux, covering:

1. **Virtual Memory in Linux** — 4-level page tables (PGD → PUD → PMD → PTE), `mm_struct`, `vm_area_struct`, TLB caching, and the `empty_zero_page` optimisation.
2. **Demand Paging Demonstration** — A C program that allocates a large array and touches pages in three access patterns (sequential, random via Fisher-Yates shuffle, stride-64), measuring minor/major page faults through `/proc/self/stat`.
3. **Page Fault Comparison using vmstat** — Shell scripts that capture `vmstat` snapshots before, during, and after the demo and produce a side-by-side comparison table.

---

## Deliverables

| File                                     | Description                                                                       |
| ---------------------------------------- | --------------------------------------------------------------------------------- |
| `Report_Memory_Management_in_Linux.docx` | Written report (≤ 10 pages) with theory, implementation, results, and SDG mapping |
| `Report_Memory_Management_in_Linux.pdf`  | PDF export of the report (viewable on GitHub)                                     |
| `Video_Class_Slide_Notes.pptx`           | 16-slide outline with ASCII diagrams and talking points (~25 min)                 |
| `Video_Class_Slide_Notes.pdf`            | PDF export of the slides (viewable on GitHub)                                     |
| `code/demand_paging_demo.c`              | C program demonstrating demand paging (3 phases × 3 patterns)                     |
| `code/compare_page_faults.sh`            | Runs all 3 patterns, prints comparison table, saves per-pattern vmstat logs       |
| `code/vmstat_monitor.sh`                 | Captures vmstat before/during/after a single pattern run                          |

---

## Build & Run

### Prerequisites

- Linux (x86-64), GCC, Bash
- `vmstat` (from `procps` / `procps-ng`)

### Compile the demo

```bash
cd code
gcc -O0 -o demand_paging_demo demand_paging_demo.c
```

`-O0` prevents the compiler from optimising away page touches.

### Run a single pattern

```bash
./demand_paging_demo sequential   # or: random, stride
```

### Run all patterns with vmstat comparison

```bash
chmod +x compare_page_faults.sh vmstat_monitor.sh
./compare_page_faults.sh
```

Output is printed to the terminal and saved to `page_fault_comparison.txt`.

### Monitor a single pattern with vmstat

```bash
./vmstat_monitor.sh sequential
```

Produces `vmstat_before_sequential.log`, `vmstat_during_sequential.log`, `vmstat_after_sequential.log`, and `vmstat_summary_sequential.txt`.

---

## References

1. Silberschatz, Galvin & Gagne — _Operating System Concepts_, 10th ed. (2018), Ch. 9–10
2. Arpaci-Dusseau & Arpaci-Dusseau — _Operating Systems: Three Easy Pieces_, Ch. 18–23
3. Robert Love — _Linux Kernel Development_, 3rd ed., Ch. 15
4. Bovet & Cesati — _Understanding the Linux Kernel_, 3rd ed., Ch. 2, 8–9
5. Mel Gorman — _Understanding the Linux Virtual Memory Manager_, Ch. 4
6. `vmstat(8)` man page
7. `proc_pid_stat(5)` man page — https://man7.org/linux/man-pages/man5/proc_pid_stat.5.html
8. United Nations Sustainable Development Goals — https://sdgs.un.org/goals
