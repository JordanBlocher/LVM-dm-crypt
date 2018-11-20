#include <stdio.h>
    
int AddHashes(int a, int b, int bLen)
{
    return a * (65599^(bLen)) + b;
}

int main(int argc, char **argv)
{
    int i, hash = 0;
    for(i = 1; i < argv[1][0]; ++i)
    {
        hash = 65599 * hash + argv[1][i];
    }
    printf("%d", hash ^ (hash >> 16));
    return 0;
}
    

