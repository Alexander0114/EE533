#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include <cuda.h>
#include <device_launch_parameters.h>
#include <string.h>

// CUDA kernel for convolution
__global__ void convolve_kernel(unsigned char* img, int W, int H, 
                                int* filter, int N, 
                                unsigned char* output) {
    // Calculate global thread coordinates
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    int outW = W - N + 1;
    int outH = H - N + 1;

    // Check bounds
    if (x < outW && y < outH) {
        long sum = 0;
        for (int ky = 0; ky < N; ky++) {
            for (int kx = 0; kx < N; kx++) {
                int pixelIndex = (y + ky) * W + (x + kx);
                sum += img[pixelIndex] * filter[ky * N + kx];
            }
        }

        if (sum < 0) sum = 0;
        if (sum > 255) sum = 255;

        output[y * outW + x] = (unsigned char)sum;
    }
}

// Exposed C function for Python
extern "C" __declspec(dllexport)
// Function to run Laplacian convolution on GPU
void run_laplacian_cuda(unsigned char* host_img, int W, int H, int N, unsigned char* host_output) {
        // Define built-in Laplacian filters
        int laplacian3[9] = {0, 1, 0, 1, -4, 1, 0, 1, 0};
        int laplacian4[16] = {0, 1, 1, 0, 1, -2, -2, 1, 1, -2, -2, 1, 0, 1, 1, 0};
        int laplacian5[25] = {0, 0, -1, 0, 0, 0, -1, -2, -1, 0, -1, -2, 16, -2, -1, 0, -1, -2, -1, 0, 0, 0, -1, 0, 0};

        int* selected_filter;
        if (N == 3) selected_filter = laplacian3;
        else if (N == 4) selected_filter = laplacian4;
        else if (N == 5) selected_filter = laplacian5;
        else return;

        int outW = W - N + 1;
        int outH = H - N + 1;

        unsigned char *d_img, *d_out;
        int *d_filter;

        // Allocate Device Memory
        cudaMalloc(&d_img, W * H);
        cudaMalloc(&d_filter, N * N * sizeof(int));
        cudaMalloc(&d_out, outW * outH);

        // Copy to Device
        cudaMemcpy(d_img, host_img, W * H, cudaMemcpyHostToDevice);
        cudaMemcpy(d_filter, selected_filter, N * N * sizeof(int), cudaMemcpyHostToDevice);

        // Grid/Block Configuration
        dim3 blockSize(16, 16);
        dim3 gridSize((outW + blockSize.x - 1) / blockSize.x, (outH + blockSize.y - 1) / blockSize.y);

        convolve_kernel<<<gridSize, blockSize>>>(d_img, W, H, d_filter, N, d_out);

        // Copy Back and Free
        cudaMemcpy(host_output, d_out, outW * outH, cudaMemcpyDeviceToHost);
        cudaFree(d_img); cudaFree(d_filter); cudaFree(d_out);
}
