#include <stdio.h>
#include <unistd.h>

int main(void) {
    printf("\nDMCTP userspace init\n\n");

    for (;;) {
        pid_t shell = spawn("/bin/sh.elf");
        if (shell < 0) {
            printf("init: cannot start /bin/sh.elf\n");
            return 1;
        }
        waitpid(shell, 0);
        printf("init: shell exited, restarting\n");
    }
}
