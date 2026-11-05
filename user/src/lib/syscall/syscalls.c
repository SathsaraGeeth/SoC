#include <stdarg.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <dmctp/thread.h>
#include <math/fp8.h>

#ifdef DMCTP_EXPERIMENTAL
#define DMCTP_A0 "r10"
#define DMCTP_A1 "r11"
#define DMCTP_A2 "r12"
#define DMCTP_A3 "r13"
#define DMCTP_A4 "r14"
#define DMCTP_A5 "r15"
#define DMCTP_A6 "r16"
#else
#define DMCTP_A0 "a0"
#define DMCTP_A1 "a1"
#define DMCTP_A2 "a2"
#define DMCTP_A3 "a3"
#define DMCTP_A4 "a4"
#define DMCTP_A5 "a5"
#define DMCTP_A6 "a6"
#endif

static inline intptr_t syscall0(int num) {
    register uintptr_t a0 __asm__(DMCTP_A0) = (uintptr_t)num;
    __asm__ volatile ("ecall" : "+r"(a0) :: "memory");
    return a0;
}

static inline intptr_t syscall1(int num, uintptr_t arg0) {
    register uintptr_t a0 __asm__(DMCTP_A0) = (uintptr_t)num;
    register uintptr_t a1 __asm__(DMCTP_A1) = arg0;
    __asm__ volatile ("ecall" : "+r"(a0), "+r"(a1) :: "memory");
    return a0;
}

static inline intptr_t syscall2(int num, uintptr_t arg0, uintptr_t arg1) {
    register uintptr_t a0 __asm__(DMCTP_A0) = (uintptr_t)num;
    register uintptr_t a1 __asm__(DMCTP_A1) = arg0;
    register uintptr_t a2 __asm__(DMCTP_A2) = arg1;
    __asm__ volatile ("ecall" : "+r"(a0), "+r"(a1), "+r"(a2) :: "memory");
    return a0;
}

static inline intptr_t syscall3(int num, uintptr_t arg0, uintptr_t arg1, uintptr_t arg2) {
    register uintptr_t a0 __asm__(DMCTP_A0) = (uintptr_t)num;
    register uintptr_t a1 __asm__(DMCTP_A1) = arg0;
    register uintptr_t a2 __asm__(DMCTP_A2) = arg1;
    register uintptr_t a3 __asm__(DMCTP_A3) = arg2;
    __asm__ volatile ("ecall" : "+r"(a0), "+r"(a1), "+r"(a2), "+r"(a3) :: "memory");
    return a0;
}

static inline intptr_t syscall4(int num, uintptr_t arg0, uintptr_t arg1,
                                uintptr_t arg2, uintptr_t arg3) {
    register uintptr_t a0 __asm__(DMCTP_A0) = (uintptr_t)num;
    register uintptr_t a1 __asm__(DMCTP_A1) = arg0;
    register uintptr_t a2 __asm__(DMCTP_A2) = arg1;
    register uintptr_t a3 __asm__(DMCTP_A3) = arg2;
    register uintptr_t a4 __asm__(DMCTP_A4) = arg3;
    __asm__ volatile ("ecall" : "+r"(a0), "+r"(a1), "+r"(a2), "+r"(a3), "+r"(a4) :: "memory");
    return a0;
}

static inline intptr_t syscall6(int num, uintptr_t arg0, uintptr_t arg1, uintptr_t arg2,
                                uintptr_t arg3, uintptr_t arg4, uintptr_t arg5) {
    register uintptr_t a0 __asm__(DMCTP_A0) = (uintptr_t)num;
    register uintptr_t a1 __asm__(DMCTP_A1) = arg0;
    register uintptr_t a2 __asm__(DMCTP_A2) = arg1;
    register uintptr_t a3 __asm__(DMCTP_A3) = arg2;
    register uintptr_t a4 __asm__(DMCTP_A4) = arg3;
    register uintptr_t a5 __asm__(DMCTP_A5) = arg4;
    register uintptr_t a6 __asm__(DMCTP_A6) = arg5;
    __asm__ volatile ("ecall" : "+r"(a0), "+r"(a1), "+r"(a2), "+r"(a3),
                      "+r"(a4), "+r"(a5), "+r"(a6) :: "memory");
    return a0;
}

void exit(int status) {
    (void)syscall1(SYS_EXIT, (uintptr_t)status);
    while (1) { }
}

void thread_exit(void) {
    exit(0);
    __builtin_unreachable();
}

int thread_create(thread_t *thread, thread_fn_t fn, void *arg,
                  void *stack, size_t stack_size) {
    if (!thread || !fn || !stack || stack_size < 256) return -1;
    intptr_t tid = syscall4(SYS_CLONE, (uintptr_t)fn, (uintptr_t)arg,
                            (uintptr_t)stack + stack_size, (uintptr_t)thread_exit);
    if (tid < 0) return -1;
    *thread = (thread_t)tid;
    return 0;
}

int thread_join(thread_t thread) {
    return waitpid(thread, 0) == thread ? 0 : -1;
}

int fork(void) {
    return syscall0(SYS_FORK);
}

int exec(const char *path) {
    return (int)syscall1(SYS_EXEC, (uintptr_t)path);
}

pid_t wait(int *status) {
    return (pid_t)syscall1(SYS_WAIT, (uintptr_t)status);
}

pid_t waitpid(pid_t pid, int *status) {
    register uintptr_t a0 __asm__(DMCTP_A0) = SYS_WAITPID;
    register uintptr_t a1 __asm__(DMCTP_A1) = (uintptr_t)pid;
    register uintptr_t a2 __asm__(DMCTP_A2) = (uintptr_t)status;
    __asm__ volatile ("ecall" : "+r"(a0), "+r"(a1), "+r"(a2) :: "memory");
    if (status && (pid_t)a0 > 0)
        *status = (int)a1;
    return (pid_t)a0;
}

pid_t getpid(void) {
    return (pid_t)syscall0(SYS_GETPID);
}

pid_t getppid(void) {
    return (pid_t)syscall0(SYS_GETPPID);
}

int yield(void) {
    return syscall0(SYS_YIELD);
}

int pipe(int fds[2]) {
    register uintptr_t a0 __asm__(DMCTP_A0) = SYS_PIPE_CREATE;
    register uintptr_t a1 __asm__(DMCTP_A1) = 0;
    __asm__ volatile ("ecall" : "+r"(a0), "+r"(a1) :: "memory");
    if ((intptr_t)a0 < 0) return -1;
    fds[0] = (int)a0; fds[1] = (int)a1; return 0;
}

int dup2(int oldfd, int newfd) {
    return (int)syscall2(SYS_DUP2, (uintptr_t)oldfd, (uintptr_t)newfd);
}

int kill(pid_t pid, int signal) {
    return (int)syscall2(SYS_KILL, (uintptr_t)pid, (uintptr_t)signal);
}

int procinfo(unsigned index, dmctp_procinfo_t *info) {
    return (int)syscall2(SYS_PROCINFO, index, (uintptr_t)info);
}

int open(const char *path, int flags) {
    return (int)syscall2(SYS_OPEN, (uintptr_t)path, (uintptr_t)flags);
}

int close(int fd) {
    return (int)syscall1(SYS_CLOSE, (uintptr_t)fd);
}

ssize_t read(int fd, void *buf, size_t n) {
    return (ssize_t)syscall3(SYS_READ, (uintptr_t)fd, (uintptr_t)buf, n);
}

ssize_t write(int fd, const void *buf, size_t n) {
    return (ssize_t)syscall3(SYS_WRITE, (uintptr_t)fd, (uintptr_t)buf, n);
}

int ioctl(int fd, unsigned long request, void *arg) {
    return (int)syscall3(SYS_IOCTL, (uintptr_t)fd, (uintptr_t)request, (uintptr_t)arg);
}

void *mmap(void *addr, size_t length, int prot, int flags, int fd, unsigned offset) {
    return (void *)syscall6(SYS_MMAP, (uintptr_t)addr, length,
                            (uintptr_t)prot, (uintptr_t)flags,
                            (uintptr_t)fd, (uintptr_t)offset);
}

int munmap(void *addr, size_t length) {
    return (int)syscall2(SYS_MUNMAP, (uintptr_t)addr, length);
}

int puts(const char *s) {
    size_t length = 0;
    while (s[length]) ++length;
    return (int)syscall3(SYS_WRITE, 1, (uintptr_t)s, length);
}

int getchar(void) {
    unsigned char ch;
    return read(0, &ch, 1) == 1 ? ch : -1;
}

int readdir(const char *path, unsigned index, dmctp_dirent_t *entry) {
    return (int)syscall3(SYS_READDIR, (uintptr_t)path, index, (uintptr_t)entry);
}

int sysinfo(dmctp_sysinfo_t *info) {
    return (int)syscall1(SYS_SYSINFO, (uintptr_t)info);
}

int mkdir(const char *path) {
    return (int)syscall1(SYS_MKDIR, (uintptr_t)path);
}

int unlink(const char *path) {
    return (int)syscall1(SYS_UNLINK, (uintptr_t)path);
}

int stat(const char *path, unsigned *size) {
    return (int)syscall2(SYS_STAT, (uintptr_t)path, (uintptr_t)size);
}

int rename(const char *old_path, const char *new_path) {
    return (int)syscall2(SYS_RENAME, (uintptr_t)old_path, (uintptr_t)new_path);
}

pid_t spawn(const char *path) {
    pid_t pid = fork();
    if (pid != 0)
        return pid;
    if (exec(path) < 0)
        exit(127);
    __builtin_unreachable();
}

int chdir(const char *path) { return (int)syscall1(SYS_CHDIR, (uintptr_t)path); }
char *getcwd(char *buf, size_t size) {
    return syscall2(SYS_GETCWD, (uintptr_t)buf, size) < 0 ? 0 : buf;
}

void sleep(unsigned seconds) {
    unsigned long long deadline = get_time() + (unsigned long long)seconds * 1000000000ULL;
    while (get_time() < deadline) __asm__ volatile("wfi");
}

static unsigned long long udivmod64(unsigned long long value, unsigned base,
                                    unsigned *rem) {
    unsigned long long quotient = 0;
    unsigned r = 0;

    for (int bit = 63; bit >= 0; bit--) {
        r = (r << 1) | (unsigned)((value >> bit) & 1ull);
        if (r >= base) {
            r -= base;
            quotient |= (1ull << bit);
        }
    }

    if (rem) *rem = r;
    return quotient;
}

static void append_char(char *out, int *used, int limit, char c) {
    if (*used < limit - 1) out[(*used)++] = c;
}

static int append_unsigned(char *out, int *used, int limit,
                           unsigned long long value, unsigned base,
                           int width, char pad) {
    char buf[32];
    int n = 0;
    int count = 0;

    do {
        unsigned digit;
        value = udivmod64(value, base, &digit);
        buf[n++] = (digit < 10) ? (char)('0' + digit) : (char)('a' + digit - 10);
    } while (value);

    while (n < width) {
        append_char(out, used, limit, pad);
        n++;
        count++;
    }
    while (n) {
        append_char(out, used, limit, buf[--n]);
        count++;
    }

    return count;
}

static int append_fp8(char *out, int *used, int limit, fp8_e4m3_t value,
                      int width, char pad) {
    char buf[16];
    int32_t scaled = fp8_e4m3_to_q16(value);
    uint32_t magnitude = scaled < 0 ? (uint32_t)(-scaled) : (uint32_t)scaled;
    uint32_t fraction = magnitude & 0xffffu;
    unsigned decimal = (unsigned)(((uint64_t)fraction * 1000000u) >> 16);
    int n = 0;
    int padding;
    int start = 0;

    if (scaled < 0) buf[n++] = '-';
    {
        char whole[4];
        unsigned value_whole = magnitude >> 16;
        int whole_n = 0;

        do {
            whole[whole_n++] = (char)('0' + value_whole % 10u);
            value_whole /= 10u;
        } while (value_whole);
        while (whole_n) buf[n++] = whole[--whole_n];
    }
    if (decimal) {
        char digits[6];
        int digits_n = 6;

        for (int i = 5; i >= 0; i--) {
            digits[i] = (char)('0' + decimal % 10u);
            decimal /= 10u;
        }
        while (digits_n && digits[digits_n - 1] == '0') digits_n--;
        buf[n++] = '.';
        for (int i = 0; i < digits_n; i++) buf[n++] = digits[i];
    }

    padding = width > n ? width - n : 0;
    if (padding && pad == '0' && buf[0] == '-') {
        append_char(out, used, limit, '-');
        start = 1;
    }
    while (padding--) {
        append_char(out, used, limit, pad);
    }
    for (int i = start; i < n; i++) append_char(out, used, limit, buf[i]);
    return width > n ? width : n;
}

/* DMCTP currently computes binary32 values. Variadic promotion carries those
 * values as binary64, and this compact path reverses that exact promotion
 * before fixed-point decimal formatting. */
static __attribute__((noinline)) int
append_promoted_float(char *out, int *used, int limit, double value,
                      int width, int precision, char pad) {
    union { double value; uint64_t bits; } representation = { .value = value };
    uint64_t bits = representation.bits;
    uint64_t fraction = bits & ((1ull << 52) - 1);
    unsigned exponent = (unsigned)((bits >> 52) & 0x7ffu);
    int negative = (int)(bits >> 63);
    uint64_t significand;
    uint64_t scaled;
    uint64_t decimal_scale = 1;
    unsigned decimal;
    int shift;
    int n;
    int padding;

    if (exponent == 0x7ffu) {
        const char *text = fraction ? "nan" : "inf";
        n = 3 + (!fraction && negative);
        padding = width > n ? width - n : 0;
        while (padding--) append_char(out, used, limit, pad);
        if (!fraction && negative) append_char(out, used, limit, '-');
        while (*text) append_char(out, used, limit, *text++);
        return width > n ? width : n;
    }

    if (precision < 0) precision = 6;
    if (precision > 9) precision = 9;

    if (exponent == 0 && fraction == 0) {
        scaled = 0;
    } else {
        int fp32_exponent = (int)exponent - 1023 + 127;
        significand = (1ull << 23) | (fraction >> 29);
        scaled = significand;
        for (int i = 0; i < precision; i++) {
            scaled *= 5u;
            decimal_scale *= 10u;
        }
        shift = fp32_exponent - 127 - 23 + precision;
        if (shift >= 0) {
            if (shift >= 63 || scaled > (~0ull >> shift)) {
                const char *text = "overflow";
                while (*text) append_char(out, used, limit, *text++);
                return 8;
            }
            scaled <<= shift;
        } else {
            unsigned right = (unsigned)-shift;
            if (right < 64) {
                uint64_t halfway = 1ull << (right - 1);
                scaled = (scaled + halfway) >> right;
            } else {
                scaled = 0;
            }
        }
    }

    if (precision == 0) decimal_scale = 1;
    uint64_t whole = udivmod64(scaled, (unsigned)decimal_scale, &decimal);
    int whole_digits = 1;
    for (uint64_t copy = whole; copy >= 10; whole_digits++)
        copy = udivmod64(copy, 10, 0);
    n = negative + whole_digits + (precision ? precision + 1 : 0);
    padding = width > n ? width - n : 0;
    if (negative && pad == '0') {
        append_char(out, used, limit, '-');
        negative = 0;
    }
    while (padding--) append_char(out, used, limit, pad);
    if (negative) append_char(out, used, limit, '-');
    (void)append_unsigned(out, used, limit, whole, 10, 0, ' ');
    if (precision) {
        append_char(out, used, limit, '.');
        (void)append_unsigned(out, used, limit, decimal, 10, precision, '0');
    }
    return width > n ? width : n;
}

int printf(const char *fmt, ...) {
    va_list ap;
    char out[256];
    int count = 0;
    int used = 0;

    va_start(ap, fmt);
    while (*fmt) {
        if (*fmt != '%') {
            if (used < (int)sizeof(out) - 1) out[used++] = *fmt;
            fmt++;
            count++;
            continue;
        }

        fmt++;
        char pad = ' ';
        int width = 0;
        if (*fmt == '0') {
            pad = '0';
            fmt++;
        }
        while (*fmt >= '0' && *fmt <= '9') {
            width = width * 10 + (*fmt - '0');
            fmt++;
        }
        int precision = -1;
        if (*fmt == '.') {
            precision = 0;
            fmt++;
            while (*fmt >= '0' && *fmt <= '9') {
                precision = precision * 10 + (*fmt - '0');
                fmt++;
            }
        }
        int length = 0;
        if (*fmt == 'l') {
            length = 1;
            fmt++;
            if (*fmt == 'l') {
                length = 2;
                fmt++;
            }
        }

        switch (*fmt) {
        case 'c': {
            char c = (char)va_arg(ap, int);
            append_char(out, &used, sizeof(out), c);
            count++;
            break;
        }
        case 's': {
            const char *s = va_arg(ap, const char *);
            if (!s) s = "(null)";
            while (*s) {
                append_char(out, &used, sizeof(out), *s);
                s++;
                count++;
            }
            break;
        }
        case 'd': {
            long long v = length == 2 ? va_arg(ap, long long) :
                          length == 1 ? va_arg(ap, long) :
                                        va_arg(ap, int);
            unsigned long long u = v < 0 ? (unsigned long long)(-v)
                                         : (unsigned long long)v;
            if (v < 0) {
                append_char(out, &used, sizeof(out), '-');
                count++;
            }
            count += append_unsigned(out, &used, sizeof(out), u, 10, width, pad);
            break;
        }
        case 'u': {
            unsigned long long u = length == 2 ? va_arg(ap, unsigned long long) :
                                   length == 1 ? va_arg(ap, unsigned long) :
                                                 va_arg(ap, unsigned);
            count += append_unsigned(out, &used, sizeof(out), u, 10, width, pad);
            break;
        }
        case 'x': {
            unsigned long long u = length == 2 ? va_arg(ap, unsigned long long) :
                                   length == 1 ? va_arg(ap, unsigned long) :
                                                 va_arg(ap, unsigned);
            count += append_unsigned(out, &used, sizeof(out), u, 16, width, pad);
            break;
        }
        case 'F': {
            fp8_e4m3_t value = (fp8_e4m3_t)va_arg(ap, int);
            count += append_fp8(out, &used, sizeof(out), value, width, pad);
            break;
        }
        case 'f': {
            double value = va_arg(ap, double);
            count += append_promoted_float(out, &used, sizeof(out), value,
                                           width, precision, pad);
            break;
        }
        case '%':
            append_char(out, &used, sizeof(out), '%');
            count++;
            break;
        default:
            append_char(out, &used, sizeof(out), '%');
            if (*fmt) append_char(out, &used, sizeof(out), *fmt);
            count += 2;
            break;
        }
        if (*fmt) fmt++;
    }
    va_end(ap);
    out[used] = '\0';
    if (used) (void)puts(out);
    return count;
}

unsigned long long get_time(void) {
    return (unsigned long long)syscall0(SYS_CLOCK_GETTIME);
}
