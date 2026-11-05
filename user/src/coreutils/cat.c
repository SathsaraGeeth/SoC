#include <unistd.h>
int main(void) {
    char path[96]; unsigned used = 0;
    puts("file: ");
    for (;;) {
        int c = getchar();
        if (c == '\r' || c == '\n') { puts("\n"); break; }
        if (c >= 32 && c < 127 && used + 1 < sizeof(path)) {
            path[used++] = (char)c; char ch = (char)c; write(1, &ch, 1);
        }
    }
    path[used] = 0;
    int fd = open(path, O_RDONLY);
    if (fd < 0) { puts("cat: cannot open file\n"); return 1; }
    char buf[128];
    for (;;) {
        int n = (int)read(fd, buf, sizeof(buf));
        if (n <= 0) { close(fd); return n < 0; }
        write(1, buf, (unsigned)n);
    }
}
