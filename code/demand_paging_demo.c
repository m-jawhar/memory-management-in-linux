/*
 * demand_paging_demo.c
 * -------------------------------------------------------------------
 * Demonstrates demand paging behaviour in Linux.
 *
 * The program allocates a large block of memory with malloc (pages are
 * NOT yet physically mapped – they exist only in virtual address space).
 * It then touches pages in configurable patterns so that page faults
 * can be observed with vmstat / /proc/self/stat.
 *
 * Compile : gcc -O0 -o demand_paging_demo demand_paging_demo.c
 * Run     : ./demand_paging_demo [size_MB] [pattern]
 *             size_MB  – amount of memory to allocate (default 512)
 *             pattern  – access pattern: seq | random | stride
 *
 * Monitor (in another terminal):
 *     vmstat 1            # watch si/so and page-fault columns
 *     or run the companion script: bash vmstat_monitor.sh
 *
 * Author  : Self-Learning Practice – Operating Systems (B24CS2T04)
 * -------------------------------------------------------------------
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* ---- helpers ---------------------------------------------------- */

static long page_size;               /* system page size in bytes     */

/* Read minor (demand-paging) and major (disk) faults from /proc/self/stat.
 * Per proc_pid_stat(5): field 10 = minflt (%lu), field 12 = majflt (%lu).
 * NOTE: Field 2 (comm) is in parentheses and may contain spaces; our
 * strtok-based parser works only if the executable name has no spaces.
 */
static void read_page_faults(long *minor, long *major)
{
    FILE *fp = fopen("/proc/self/stat", "r");
    if (!fp) { *minor = *major = -1; return; }

    /* Fields 10 and 12 (1-indexed) are minflt and majflt.             */
    long minflt = 0, majflt = 0;
    /* Skip first 9 fields */
    int field = 0;
    char buf[4096];
    if (fgets(buf, sizeof(buf), fp)) {
        char *tok = strtok(buf, " ");
        while (tok) {
            field++;
            if (field == 10) minflt = atol(tok);
            if (field == 12) majflt = atol(tok);
            if (field >= 12) break;
            tok = strtok(NULL, " ");
        }
    }
    fclose(fp);
    *minor = minflt;
    *major = majflt;
}

/* ---- access-pattern functions ----------------------------------- */

/*
 * Sequential access – touches every page exactly once in order.
 * Expected: a burst of minor page faults equal to total_pages.
 */
static void access_sequential(volatile char *mem, size_t size)
{
    printf("[SEQ] Touching every page sequentially ...\n");
    for (size_t off = 0; off < size; off += page_size)
        mem[off] = (char)(off & 0xFF);
}

/*
 * Random access – touches every page exactly once in random order
 * using a Fisher-Yates (Knuth) shuffle of page indices.
 * Expected: same total faults as sequential, but more TLB misses.
 */
static void access_random(volatile char *mem, size_t size)
{
    size_t total_pages = size / page_size;
    printf("[RND] Touching %zu pages in random order (Fisher-Yates shuffle) ...\n", total_pages);

    /* Build an index array and shuffle it so every page is visited once */
    size_t *indices = (size_t *)malloc(total_pages * sizeof(size_t));
    if (!indices) { perror("malloc indices"); return; }
    for (size_t i = 0; i < total_pages; i++) indices[i] = i;

    srand((unsigned)time(NULL));
    for (size_t i = total_pages - 1; i > 0; i--) {
        size_t j = (size_t)rand() % (i + 1);
        size_t tmp = indices[i];
        indices[i] = indices[j];
        indices[j] = tmp;
    }

    for (size_t i = 0; i < total_pages; i++)
        mem[indices[i] * page_size] = (char)(indices[i] & 0xFF);

    free(indices);
}

/*
 * Stride access – touches every N-th page, then wraps around.
 * Useful for showing how locality affects TLB / page-fault cost.
 */
static void access_stride(volatile char *mem, size_t size)
{
    size_t total_pages = size / page_size;
    size_t stride = 64;                           /* skip 64 pages   */
    printf("[STRIDE] Touching pages with stride=%zu ...\n", stride);
    for (size_t pass = 0; pass < stride; pass++)
        for (size_t pg = pass; pg < total_pages; pg += stride)
            mem[pg * page_size] = (char)(pg & 0xFF);
}

/* ---- main ------------------------------------------------------- */

int main(int argc, char *argv[])
{
    /* Defaults */
    size_t size_mb = 512;
    const char *pattern = "seq";

    if (argc >= 2) size_mb  = (size_t)atol(argv[1]);
    if (argc >= 3) pattern  = argv[2];

    page_size = sysconf(_SC_PAGESIZE);
    size_t size = size_mb * 1024UL * 1024UL;
    size_t total_pages = size / page_size;

    printf("============================================\n");
    printf("  Demand Paging Demonstration\n");
    printf("============================================\n");
    printf("  Page size       : %ld bytes\n", page_size);
    printf("  Allocation      : %zu MB  (%zu pages)\n", size_mb, total_pages);
    printf("  Access pattern  : %s\n", pattern);
    printf("============================================\n\n");

    /* --- Phase 1 : Allocate (no pages are physically mapped yet) --- */
    long min0, maj0;
    read_page_faults(&min0, &maj0);
    printf("[Phase 1] malloc(%zu MB) – only virtual addresses reserved.\n", size_mb);

    volatile char *mem = (volatile char *)malloc(size);
    if (!mem) { perror("malloc"); return 1; }

    long min1, maj1;
    read_page_faults(&min1, &maj1);
    printf("  Page faults after malloc  : minor=%ld  major=%ld\n",
           min1 - min0, maj1 - maj0);
    printf("  (Expect ~0 because no physical frames allocated yet.)\n\n");

    /* Small pause so vmstat captures the baseline */
    sleep(2);

    /* --- Phase 2 : Touch pages (demand paging occurs here) -------- */
    long min2, maj2;
    read_page_faults(&min2, &maj2);
    printf("[Phase 2] Touching pages – demand paging in action.\n");

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    if      (strcmp(pattern, "seq")    == 0) access_sequential(mem, size);
    else if (strcmp(pattern, "random") == 0) access_random(mem, size);
    else if (strcmp(pattern, "stride") == 0) access_stride(mem, size);
    else {
        fprintf(stderr, "Unknown pattern '%s'. Use: seq | random | stride\n", pattern);
        free((void *)mem);
        return 1;
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);

    long min3, maj3;
    read_page_faults(&min3, &maj3);

    double elapsed = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;

    printf("\n  Page faults during access  : minor=%ld  major=%ld\n",
           min3 - min2, maj3 - maj2);
    printf("  Time elapsed               : %.4f seconds\n", elapsed);
    printf("  Approx faults / second     : %.0f\n\n",
           (min3 - min2) / elapsed);

    /* --- Phase 3 : Re-access (pages already in memory) ------------ */
    printf("[Phase 3] Re-touching all pages (should cause ~0 new faults).\n");
    long min4, maj4;
    read_page_faults(&min4, &maj4);

    access_sequential(mem, size);                 /* always sequential */

    long min5, maj5;
    read_page_faults(&min5, &maj5);
    printf("  Page faults on re-access   : minor=%ld  major=%ld\n",
           min5 - min4, maj5 - maj4);
    printf("  (Expect ~0 because frames are already mapped.)\n\n");

    /* --- Cleanup -------------------------------------------------- */
    free((void *)mem);

    printf("============================================\n");
    printf("  Summary\n");
    printf("============================================\n");
    printf("  Total minor faults  : %ld\n", min5 - min0);
    printf("  Total major faults  : %ld\n", maj5 - maj0);
    printf("============================================\n");

    return 0;
}
