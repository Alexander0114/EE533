#include <stdio.h>

// GPU Kernel: Each thread adds one element
__global__ void add(int *a, int *b, int *c, int n) {
    int index = threadIdx.x + blockIdx.x * blockDim.x;
    if (index < n) c[index] = a[index] + b[index];
}

int main() {
    int n = 512; // Number of elements
    int size = n * sizeof(int);
    
    // Allocate host memory
    int *h_a, *h_b, *h_c;
    h_a = (int*)malloc(size);
    h_b = (int*)malloc(size);
    h_c = (int*)malloc(size);

    // Initialize arrays
    for(int i=0; i<n; i++) { h_a[i] = i; h_b[i] = i; }

    // Allocate GPU memory
    int *d_a, *d_b, *d_c;
    cudaMalloc((void **)&d_a, size);
    cudaMalloc((void **)&d_b, size);
    cudaMalloc((void **)&d_c, size);

    // Copy data from Host (CPU) to Device (GPU)
    cudaMemcpy(d_a, h_a, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_b, h_b, size, cudaMemcpyHostToDevice);

    // Launch kernel on GPU
    add<<<2, 256>>>(d_a, d_b, d_c, n);

    // Copy result back to Host
    cudaMemcpy(h_c, d_c, size, cudaMemcpyDeviceToHost);

    printf("Success! %d + %d = %d\n", h_a[5], h_b[5], h_c[5]);

    // Cleanup
    cudaFree(d_a); cudaFree(d_b); cudaFree(d_c);
    free(h_a); free(h_b); free(h_c);
    return 0;
}