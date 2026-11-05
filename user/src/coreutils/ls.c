#include <unistd.h>

int main(void) {
    dmctp_dirent_t ent;
    for (unsigned i = 0;; i++) {
        int result = readdir("/bin", i, &ent);
        if (result < 0) { puts("ls: cannot read /bin\n"); return 1; }
        if (result == 0) break;
        printf("%s\n", ent.name);
    }
    return 0;
}
