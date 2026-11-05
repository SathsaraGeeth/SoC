#include <dmctp/syscalls.h>

int main(int argc, char **argv) {
    int a = 5;
    int b = 3;
    int sum = a + b;
    int diff = a - b;
    int prod = a * b;
    int quot = a / b;

    printf("Sum: %d\n", sum);
    printf("Difference: %d\n", diff);
    printf("Product: %d\n", prod);
    printf("Quotient: %d\n", quot);

    return 0;
}
