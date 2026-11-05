#include <unistd.h>

static int same(const char *a, const char *b) {
    while (*a && *b && *a == *b) { a++; b++; }
    return *a == *b;
}

static unsigned length(const char *s) { unsigned n = 0; while (s[n]) n++; return n; }

static void copy_text(char *dst, const char *src, unsigned cap) {
    unsigned i = 0; while (i + 1 < cap && src[i]) { dst[i] = src[i]; i++; } dst[i] = 0;
}

static char *next_arg(char **cursor) {
    char *p = *cursor;
    while (*p == ' ') p++;
    if (!*p) { *cursor = p; return p; }
    char *result = p;
    while (*p && *p != ' ') p++;
    if (*p) *p++ = 0;
    *cursor = p;
    return result;
}

static void prompt(void) { puts("dmctp$ "); }

static int resolve_command_path(const char *command, char *path, unsigned cap) {
    unsigned size;

    if (command[0] == '/') {
        copy_text(path, command, cap);
        return stat(path, &size);
    }

    copy_text(path, "/bin/", cap);
    unsigned at = length(path), i = 0;
    while (command[i] && command[i] != ' ' && at + 1 < cap)
        path[at++] = command[i++];
    path[at] = 0;
    if (stat(path, &size) == 0) return 0;

    if (at + 5 >= cap) return -1;
    path[at++] = '.';
    path[at++] = 'e';
    path[at++] = 'l';
    path[at++] = 'f';
    path[at] = 0;
    return stat(path, &size);
}

static void cat_file(const char *path) {
    char buf[96];
    int fd = path && *path ? open(path, O_RDONLY) : 0;
    if (fd < 0) { puts("cat: cannot open file\n"); return; }
    for (;;) {
        int n = (int)read(fd, buf, sizeof(buf));
        if (n < 0) { puts("cat: read error\n"); break; }
        if (n == 0) break;
        (void)write(1, buf, (unsigned)n);
    }
    if (fd != 0) (void)close(fd);
}

static void list_dir(const char *path) {
    dmctp_dirent_t ent;
    if (!path || !*path) path = ".";
    for (unsigned i = 0;; i++) {
        int result = readdir(path, i, &ent);
        if (result <= 0) { if (result < 0) puts("ls: read error\n"); return; }
        printf("%s\n", ent.name);
    }
}

static void show_cpu(void) {
    dmctp_sysinfo_t i;
    if (sysinfo(&i) < 0) { puts("lscpu: sysinfo failed\n"); return; }
    unsigned clusters = i.clusters;
    unsigned cpu_per_cluster = i.threads_per_cluster;
    unsigned total_cpus = i.cpu_count;
    unsigned sys_per_cluster = i.sys_cores_per_cluster;
    unsigned total_sys_cores = i.sys_core_count;
    const char *arch = i.sys_array_arch == DMCTP_SYS_ARRAY_MAC20I
        ? "int8i.int32i.int8i" : i.sys_array_arch == DMCTP_SYS_ARRAY_MACFP8
        ? "fp8.fp32.fp8" : i.sys_array_arch == DMCTP_SYS_ARRAY_MACFP8INT8
        ? "fp8&int8.runtime" : "unknown";
    puts("Architecture:    dmctp SoC\n");
    puts("CPU Arch:        dmctp64\n");
    printf("Clusters:        %u\nThreads/Clus:    %u\nTotal CPUs:      %u\nSys Cores/Clus:  %u\nTotal Sys Cores: %u\n",
           clusters, cpu_per_cluster, total_cpus, sys_per_cluster, total_sys_cores);
    printf("Sys Core Arch:   %s | native: %ux%u | dense: %ux%u\n",
           arch, i.sys_array_m, i.sys_array_m,
           i.sys_array_max_dense, i.sys_array_max_dense);
}

static void show_free(void) {
    dmctp_sysinfo_t i;
    if (sysinfo(&i) < 0) { puts("free: sysinfo failed\n"); return; }
    printf("Memory Regions: %u\n", i.memory_regions);
    printf("RAM per region: %u bytes\n", i.ram_per_region);
    printf("Total RAM:      %u bytes\n", i.memory_regions * i.ram_per_region);
    printf("\nprocs:  %u / %u\n", i.process_count, i.process_limit);
    puts("heap:   slab allocator active\n");
}

static void edit_file(const char *path) {
    if (!*path) { puts("usage: nano <path>\n"); return; }
    char text[512]; unsigned n = 0;
    puts("Enter one line (replaces file):\n");
    for (;;) {
        int c = getchar();
        if (c == '\r' || c == '\n') { puts("\n"); break; }
        if ((c == 8 || c == 127) && n) { n--; write(1, "\b \b", 3); }
        else if (c >= 32 && c < 127 && n + 2 < sizeof(text)) {
            text[n++] = (char)c; char echo = (char)c; write(1, &echo, 1);
        }
    }
    text[n++] = '\n';
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC);
    if (fd < 0) { puts("nano: cannot open file\n"); return; }
    int wrote = (int)write(fd, text, n); close(fd);
    puts(wrote == (int)n ? "saved\n" : "nano: write failed\n");
}

static int copy_file(const char *source, const char *destination) {
    char buf[256];
    int in = open(source, O_RDONLY);
    if (in < 0) { puts("cp: cannot open source\n"); return -1; }
    int out = open(destination, O_WRONLY | O_CREAT | O_TRUNC);
    if (out < 0) { close(in); puts("cp: cannot open destination\n"); return -1; }
    for (;;) {
        int n = (int)read(in, buf, sizeof(buf));
        if (n == 0) break;
        if (n < 0 || write(out, buf, (unsigned)n) != n) {
            puts("cp: I/O error\n"); close(in); close(out); return -1;
        }
    }
    close(in); close(out); return 0;
}

static void echo_command(char *text) {
    write(1, text, length(text));
    write(1, "\n", 1);
}

#define MAX_JOBS 8
static pid_t jobs[MAX_JOBS];
static pid_t job_aux[MAX_JOBS];
static char job_names[MAX_JOBS][32];

static void add_job_pair(pid_t pid, pid_t aux, const char *name) {
    for (int i = 0; i < MAX_JOBS; i++) if (!jobs[i]) {
        jobs[i] = pid; job_aux[i] = aux; copy_text(job_names[i], name, sizeof(job_names[i]));
        printf("[%d] %d\n", i + 1, pid); return;
    }
    puts("shell: job table full\n");
}
static void add_job(pid_t pid, const char *name) { add_job_pair(pid, 0, name); }

static void launch(char *command, int background) {
    char path[96];
    if (resolve_command_path(command, path, sizeof(path)) < 0) {
        printf("%s: command not found\n", command);
        return;
    }
    pid_t pid = spawn(path);
    if (pid < 0) { printf("%s: failed to start\n", command); return; }
    if (!background) {
        int status = -1;
        if (waitpid(pid, &status) == pid)
            printf("%s: exited status=%d\n", command, status);
        else
            printf("%s: wait failed\n", command);
    } else {
        add_job(pid, command);
    }
}

static void show_jobs(void) {
    for (int i = 0; i < MAX_JOBS; i++) if (jobs[i]) {
        dmctp_procinfo_t p; const char *state = "done";
        for (unsigned n = 0; procinfo(n, &p) > 0; n++) if (p.pid == jobs[i]) {
            state = p.state == DMCTP_PROC_RUNNING ? "running" :
                    p.state == DMCTP_PROC_READY ? "ready" :
                    p.state == DMCTP_PROC_BLOCKED ? "blocked" :
                    p.state == DMCTP_PROC_ZOMBIE ? "done" : "dead";
            break;
        }
        printf("[%d] %d %s %s\n", i + 1, jobs[i], state, job_names[i]);
    }
}

static void stream_wc(void) {
    char b[128]; unsigned lines = 0, words = 0, bytes = 0; int inword = 0, n;
    while ((n = (int)read(0, b, sizeof(b))) > 0) for (int i = 0; i < n; i++) {
        char c = b[i]; bytes++; if (c == '\n') lines++;
        int space = c == ' ' || c == '\n' || c == '\t' || c == '\r';
        if (!space && !inword) words++; inword = !space;
    }
    printf("%u %u %u\n", lines, words, bytes);
}

static void stream_head(void) {
    char c; unsigned lines = 0;
    while (lines < 10 && read(0, &c, 1) == 1) { write(1, &c, 1); if (c == '\n') lines++; }
}

static void stream_grep(const char *needle) {
    char line[256]; unsigned n = 0; char c;
    if (!needle || !*needle) { puts("usage: grep STRING\n"); return; }
    while (read(0, &c, 1) == 1) {
        if (n + 1 < sizeof(line)) line[n++] = c;
        if (c == '\n') {
            line[n] = 0; int found = 0;
            for (unsigned i = 0; line[i] && !found; i++) {
                unsigned j = 0; while (needle[j] && line[i + j] == needle[j]) j++;
                if (!needle[j]) found = 1;
            }
            if (found) write(1, line, n); n = 0;
        }
    }
    if (n) { line[n] = 0; for (unsigned i = 0; line[i]; i++) {
        unsigned j = 0; while (needle[j] && line[i+j] == needle[j]) j++;
        if (!needle[j]) { write(1, line, n); break; }
    }}
}

static void show_ps(void) {
    puts("PID  PPID STATE    NAME\n");
    dmctp_procinfo_t p;
    for (unsigned i = 0; procinfo(i, &p) > 0; i++) if (p.state != DMCTP_PROC_DEAD) {
        const char *s = p.state == DMCTP_PROC_RUNNING ? "RUNNING" : p.state == DMCTP_PROC_READY ? "READY" :
                        p.state == DMCTP_PROC_BLOCKED ? "BLOCKED" : "ZOMBIE";
        printf("%u %u %s %s\n", (unsigned)p.pid, (unsigned)p.ppid, s, p.name);
    }
}

static void run_stage(char *text) {
    char *cursor = text, *cmd = next_arg(&cursor), *arg = cursor; while (*arg == ' ') arg++;
    if (same(cmd, "echo")) echo_command(arg);
    else if (same(cmd, "cat")) cat_file(arg);
    else if (same(cmd, "wc")) stream_wc();
    else if (same(cmd, "head")) stream_head();
    else if (same(cmd, "grep")) stream_grep(arg);
    else if (same(cmd, "lscpu")) show_cpu();
    else if (same(cmd, "free")) show_free();
    else if (same(cmd, "ps")) show_ps();
    else {
        char path[96];
        if (resolve_command_path(cmd, path, sizeof(path)) < 0) printf("%s: command not found\n", cmd);
        else if (exec(path) < 0) printf("%s: failed to start\n", cmd);
    }
}

static char *trim(char *s) { while (*s == ' ') s++; char *e = s + length(s); while (e > s && e[-1] == ' ') *--e = 0; return s; }

static int redirect_stage(char *stage, int *infd, int *outfd) {
    for (char *p = stage; *p; p++) if (*p == '<' || *p == '>') {
        char op = *p; int append = op == '>' && p[1] == '>'; char *begin = p;
        char *name = p + 1 + append; while (*name == ' ') name++;
        char *end = name; while (*end && *end != ' ' && *end != '<' && *end != '>') end++;
        char saved = *end; *end = 0;
        int fd = open(name, op == '<' ? O_RDONLY : O_WRONLY | O_CREAT | (append ? O_APPEND : O_TRUNC));
        *end = saved; if (fd < 0) return -1;
        if (op == '<') { if (*infd > 2) close(*infd); *infd = fd; }
        else { if (*outfd > 2) close(*outfd); *outfd = fd; }
        for (char *q = begin; q < end; q++) *q = ' ';
        p = end - 1;
    }
    (void)trim(stage); return 0;
}

static pid_t fork_stage(char *stage, int infd, int outfd) {
    pid_t pid = fork();
    if (pid == 0) {
        if (infd != 0) dup2(infd, 0); if (outfd != 1) dup2(outfd, 1);
        for (int fd = 3; fd < 16; fd++) close(fd);
        run_stage(trim(stage)); exit(0);
    }
    return pid;
}

static int is_io_builtin(const char *stage) {
    char name[16]; unsigned n = 0; while (*stage == ' ') stage++;
    while (*stage && *stage != ' ' && n + 1 < sizeof(name)) name[n++] = *stage++;
    name[n] = 0;
    return same(name, "echo") || same(name, "cat") || same(name, "wc") ||
           same(name, "head") || same(name, "grep") || same(name, "lscpu") ||
           same(name, "free") || same(name, "ps");
}

static void execute_io(char *line, int background) {
    char *bar = 0; for (char *p = line; *p; p++) if (*p == '|') { bar = p; break; }
    int left_in = 0, left_out = 1, right_in = 0, right_out = 1, pfds[2] = {-1,-1};
    char *right = 0; if (bar) { *bar = 0; right = trim(bar + 1); if (pipe(pfds) < 0) { puts("pipe: failed\n"); return; } left_out = pfds[1]; right_in = pfds[0]; }
    if (redirect_stage(line, &left_in, &left_out) < 0 || (right && redirect_stage(right, &right_in, &right_out) < 0)) { puts("redirection: failed\n"); return; }
    if (!right && !background && is_io_builtin(line)) {
        int saved_in = dup2(0, 14);
        int saved_out = dup2(1, 15);
        if (left_in != 0) dup2(left_in, 0); if (left_out != 1) dup2(left_out, 1);
        run_stage(trim(line));
        if (saved_in >= 0) { dup2(saved_in, 0); close(saved_in); }
        if (saved_out >= 0) { dup2(saved_out, 1); close(saved_out); }
        if (left_in > 2) close(left_in); if (left_out > 2) close(left_out);
        return;
    }
    pid_t left = fork_stage(line, left_in, left_out); pid_t last = left;
    if (right) { if (pfds[1] > 2) close(pfds[1]); last = fork_stage(right, right_in, right_out); if (pfds[0] > 2) close(pfds[0]); }
    if (left_in > 2) close(left_in); if (right_out > 2) close(right_out);
    if (background) add_job_pair(last, right && last != left ? left : 0, right ? right : line);
    else { waitpid(left, 0); if (right && last != left) waitpid(last, 0); }
}

int main(void) {
    char line[64];
    for (int i = 0; i < MAX_JOBS; i++) { jobs[i] = 0; job_aux[i] = 0; job_names[i][0] = 0; }
    puts("\n");
    puts("  ____  __  __  ____ _____ ____  \n");
    puts(" |  _ \\|  \\/  |/ ___|_   _|  _ \\ \n");
    puts(" | | | | |\\/| | |     | | | |_) |\n");
    puts(" | |_| | |  | | |___  | | |  __/ \n");
    puts(" |____/|_|  |_|\\____| |_| |_|    \n");
    puts("\nDMCTP shell\n\n");
    for (;;) {
        unsigned n = 0;
        prompt();
        for (;;) {
            int c = getchar();
            if (c == '\r' || c == '\n') { puts("\n"); break; }
            if ((c == 8 || c == 127) && n) {
                n--;
                (void)write(1, "\b \b", 3);
            } else if (c >= 32 && c < 127 && n + 1 < sizeof(line)) {
                line[n++] = (char)c;
                char echo = (char)c;
                (void)write(1, &echo, 1);
            }
        }
        line[n] = 0;
        int background = 0;
        while (n && line[n - 1] == ' ') line[--n] = 0;
        if (n && line[n - 1] == '&') {
            background = 1; line[--n] = 0;
            while (n && line[n - 1] == ' ') line[--n] = 0;
        }
        int has_io = 0; for (unsigned i = 0; line[i]; i++) if (line[i] == '<' || line[i] == '>' || line[i] == '|') has_io = 1;
        if (has_io) { execute_io(line, background); continue; }
        char original[64]; copy_text(original, line, sizeof(original));
        char *cursor = line;
        char *command = next_arg(&cursor);
        char *arg = cursor; while (*arg == ' ') arg++;
        if (same(command, "exit")) return 0;
        if (same(command, "help")) puts("help pwd cd ls lscpu free cat nano echo mkdir touch rm cp mv wc head grep ps kill sleep jobs fg exit\n");
        else if (same(command, "pwd")) {
            char cwd[128]; if (getcwd(cwd, sizeof(cwd))) printf("%s\n", cwd); else puts("pwd: failed\n");
        }
        else if (same(command, "cd")) {
            if (!*arg) arg = "/";
            if (chdir(arg) < 0) printf("cd: %s: no such directory\n", arg);
        }
        else if (same(command, "ls")) list_dir(arg);
        else if (same(command, "lscpu")) show_cpu();
        else if (same(command, "free")) show_free();
        else if (same(command, "echo")) echo_command(arg);
        else if (same(command, "mkdir")) { if (!*arg || mkdir(arg) < 0) puts("mkdir: failed\n"); }
        else if (same(command, "touch")) {
            int fd = *arg ? open(arg, O_WRONLY | O_CREAT) : -1;
            if (fd < 0) puts("touch: failed\n"); else close(fd);
        }
        else if (same(command, "rm")) { if (!*arg || unlink(arg) < 0) puts("rm: failed\n"); }
        else if (same(command, "cp") || same(command, "mv")) {
            char *args = arg, *from = next_arg(&args), *to = next_arg(&args);
            if (!*from || !*to) puts(same(command, "cp") ? "usage: cp SOURCE DEST\n" : "usage: mv OLD NEW\n");
            else if (same(command, "cp")) copy_file(from, to);
            else if (rename(from, to) < 0) puts("mv: rename failed\n");
        }
        else if (same(command, "jobs")) show_jobs();
        else if (same(command, "wc")) stream_wc();
        else if (same(command, "head")) stream_head();
        else if (same(command, "grep")) stream_grep(arg);
        else if (same(command, "ps")) show_ps();
        else if (same(command, "kill")) {
            int pid = 0; for (char *p = arg; *p >= '0' && *p <= '9'; p++) pid = pid * 10 + (*p - '0');
            if (!pid || kill(pid, 2) < 0) puts("kill: failed\n");
        }
        else if (same(command, "sleep")) {
            unsigned seconds = 0; for (char *p = arg; *p >= '0' && *p <= '9'; p++) seconds = seconds * 10 + (unsigned)(*p - '0');
            if (background) {
                pid_t pid = fork(); if (pid == 0) { sleep(seconds); exit(0); } if (pid > 0) add_job(pid, original);
            } else sleep(seconds);
        }
        else if (same(command, "fg")) {
            int slot = *arg ? arg[0] - '1' : -1;
            if (slot < 0 || slot >= MAX_JOBS || !jobs[slot]) puts("fg: no such job\n");
            else {
                if (job_aux[slot]) waitpid(job_aux[slot], 0);
                waitpid(jobs[slot], 0); jobs[slot] = 0; job_aux[slot] = 0;
            }
        }
        else if (same(command, "cat")) {
            if (*arg) cat_file(arg); else puts("usage: cat <path>\n");
        }
        else if (same(command, "nano")) edit_file(arg);
        else if (command[0]) launch(original, background);
    }
}
