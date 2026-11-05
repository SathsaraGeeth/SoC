#include <unistd.h>

static unsigned get_line(char *buf, unsigned capacity) {
    unsigned used = 0;
    for (;;) {
        int c = getchar();
        if (c == '\r' || c == '\n') { puts("\n"); break; }
        if ((c == 8 || c == 127) && used) {
            used--; write(1, "\b \b", 3);
        } else if (c >= 32 && c < 127 && used + 1 < capacity) {
            buf[used++] = (char)c; char ch = (char)c; write(1, &ch, 1);
        }
    }
    buf[used] = 0;
    return used;
}

int main(void) {
    char path[96], text[512];
    puts("nano file: ");
    if (!get_line(path, sizeof(path))) return 1;
    puts("Enter one line (the file will be replaced):\n");
    unsigned length = get_line(text, sizeof(text) - 1);
    text[length++] = '\n';
    int fd = open(path, O_WRONLY | O_CREAT | O_TRUNC);
    if (fd < 0) { puts("nano: cannot open file\n"); return 1; }
    int result = (int)write(fd, text, length);
    close(fd);
    if (result != (int)length) { puts("nano: write failed\n"); return 1; }
    puts("saved\n");
    return 0;
}
