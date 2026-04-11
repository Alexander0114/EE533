#include <stdio.h>
#include <stdlib.h>
#include <time.h>

void matrixMultiplyCPU(float *A, float *B, float *C, int N) {
	for (int i = 0; i < N; i++) {
		for (int j=0; j < N; j++) {
			float sum = 0.0f;
			for(int k = 0; k < N; k++) {
				sum += A[i*N + k] * B[k*N + j];		
			}
			C[i*N + j] = sum;
		}
	}
}

__global__ void matrixMultiplyGPU(float *A, float *B, float *C, int N) {
	 int row = blockIdx.y * blockDim.y + threadIdx.y;
	 int col = blockIdx.x * blockDim.x + threadIdx.x;

	 if (row < N && col < N) {
		float sum = 0.0f;
		for (int k = 0; k < N; k++) {
	 		sum += A[row * N + k] * B[k * N + col];
	 	}
	 	C[row * N + col] = sum;
	 }
} 

int main(int argc, char **argv) {
	 int N = (argc > 1) ? atoi(argv[1]) : 1024; // allow matrix size as input
	 size_t size = N * N * sizeof(float);
	
	 float *A = (float *)malloc(size);
	 float *B = (float *)malloc(size);
	 float *C = (float *)malloc(size);

	for (int i = 0; i < N * N; i++) {
		A[i] = rand() % 100 / 100.0f;
	 	B[i] = rand() % 100 / 100.0f;
	}

	// CUDA memory
	float *c_A, *c_B, *c_C;
	cudaMalloc(&c_A, size);
	cudaMalloc(&c_B, size);
	cudaMalloc(&c_C, size);

    // copy data to devides
	cudaMemcpy(&A, c_A, size, cudaMemcpyHostToDevice);
	cudaMemcpy(&B, c_B, size, cudaMemcpyHostToDevice);

	// announce block size and grid format
	dim3 block(16, 16);
	dim3 grid((N + block.x - 1) / block.x, (N + block.y - 1) / block.y);

    // GPU timing, as previous timing seems odd
    cudaEvent_t start_gpu, stop_gpu;
    cudaEventCreate(&start_gpu);
    cudaEventCreate(&stop_gpu);

    cudaEventRecord(start_gpu);
	 
	// clock_t start = clock();
	matrixMultiplyGPU<<<grid, block>>>(c_A, c_B, c_C, N);
	// clock_t end = clock();
    cudaEventRecord(stop_gpu);
    cudaEventSynchronize(stop_gpu);

    float elapsedMs;
    cudaEventElapsedTime(&elapsedMs, start_gpu, stop_gpu);

    printf("CUDA: GPU execution time (N=%d): %f MS\n", N, elapsedMs);
	 
	// double elapsed = (double)(end - start) / CLOCKS_PER_SEC;
	// printf("C: GPU execution time (N=%d): %f seconds\n", N, elapsed);
	free(A); free(B); free(C);
	cudaFree(c_A); cudaFree(c_B); cudaFree(c_C);
	return 0; 
}
