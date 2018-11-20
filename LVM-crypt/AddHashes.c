#include <stdio.h>
    

int main(int argc, char **argv)
{
    printf("%d", argv[1][1] * (65599^(argv[1][0])) + argv[1][2]);
    return 0;
}
    

