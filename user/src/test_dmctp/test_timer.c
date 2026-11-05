#include <unistd.h>

static void delay_cycles(unsigned cycles) {
    for (volatile unsigned i = 0; i < cycles; i++) { }
}

static unsigned divmod_u32(unsigned value, unsigned base, unsigned *rem) {
    unsigned q = 0, r = 0;
    for (int bit = 31; bit >= 0; bit--) {
        r = (r << 1) | ((value >> bit) & 1u);
        if (r >= base) { r -= base; q |= 1u << bit; }
    }
    *rem = r;
    return q;
}

static char *append_u32(char *p, unsigned value) {
    char digits[10];
    int n = 0;
    do {
        unsigned digit;
        value = divmod_u32(value, 10, &digit);
        digits[n++] = (char)('0' + digit);
    } while (value);
    while (n) *p++ = digits[--n];
    return p;
}

static char *append_text(char *p, const char *s) {
    while (*s) *p++ = *s++;
    return p;
}

static void print_elapsed(unsigned nanoseconds) {
    char line[48];
    char *p = line;
    unsigned remainder, tens, ones;
    unsigned microseconds = divmod_u32(nanoseconds, 1000, &remainder);
    unsigned hundreds = divmod_u32(remainder, 100, &tens);
    tens = divmod_u32(tens, 10, &ones);

    p = append_text(p, "Elapsed time: ");
    p = append_u32(p, microseconds);
    *p++ = '.';
    *p++ = (char)('0' + hundreds);
    *p++ = (char)('0' + tens);
    *p++ = (char)('0' + ones);
    p = append_text(p, " us");
    *p++ = '\n';
    *p = '\0';
    puts(line);
}

static void print_u32_line(const char *label, unsigned value, const char *suffix) {
    char line[64];
    char *p = line;

    p = append_text(p, label);
    p = append_u32(p, value);
    p = append_text(p, suffix);
    *p++ = '\n';
    *p = '\0';
    puts(line);
}

int main(void) {
    puts("--- Timer Test ---\n");

    enum { SAMPLES = 16 };
    unsigned min_delta = ~0u;
    unsigned max_delta = 0;
    unsigned total_delta = 0;

    puts("Back-to-back get_time() deltas:\n");
    for (unsigned i = 0; i < SAMPLES; i++) {
        unsigned long long start = get_time();
        unsigned long long end = get_time();
        unsigned delta = (unsigned)(end - start);

        if (delta < min_delta) min_delta = delta;
        if (delta > max_delta) max_delta = delta;
        total_delta += delta;

        print_u32_line("  delta ns: ", delta, "");
    }

    print_u32_line("min ns: ", min_delta, "");
    print_u32_line("max ns: ", max_delta, "");
    print_u32_line("avg ns: ", total_delta / SAMPLES, "");

    unsigned long long start_time = get_time();

    puts("Waiting...\n");
    delay_cycles(1000);

    unsigned long long end_time = get_time();
    unsigned long long diff = end_time - start_time;
    print_elapsed((unsigned)diff);

    return 0;
}
