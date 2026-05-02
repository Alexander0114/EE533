#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define TILE_WIDTH 16

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

__global__ void matrixMultiplyTiled(float *A, float *B, float *C, int N) {
    __shared__ float ds_A[TILE_WIDTH][TILE_WIDTH];
    __shared__ float ds_B[TILE_WIDTH][TILE_WIDTH];
    int bx = blockIdx.x; int by = blockIdx.y;
    int tx = threadIdx.x; int ty = threadIdx.y;
    int Row = by * TILE_WIDTH + ty;
    int Col = bx * TILE_WIDTH + tx;
    float Pvalue = 0.0;
    for (int m = 0; m < (N + TILE_WIDTH - 1) / TILE_WIDTH; ++m) {
        if (Row < N && (m*TILE_WIDTH+tx) < N)
        ds_A[ty][tx] = A[Row * N + m * TILE_WIDTH + tx];
    else
        ds_A[ty][tx] = 0.0f;
    if (Col < N && (m*TILE_WIDTH+ty) < N)
        ds_B[ty][tx] = B[(m*TILE_WIDTH + ty) * N + Col];
    else
        ds_B[ty][tx] = 0.0f;
        __syncthreads();
    for (int k = 0; k < TILE_WIDTH; ++k)
        Pvalue += ds_A[ty][k] * ds_B[k][tx];
        __syncthreads();
    }
    if (Row < N && Col < N)
    C[Row * N + Col] = Pvalue;
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
	dim3 block(TILE_WIDTH, TILE_WIDTH);
	dim3 grid((N + TILE_WIDTH - 1) / TILE_WIDTH, (N + TILE_WIDTH - 1) / TILE_WIDTH);

    // GPU timing, as previous timing seems odd
    cudaEvent_t start_gpu, stop_gpu;
    cudaEventCreate(&start_gpu);
    cudaEventCreate(&stop_gpu);

    cudaEventRecord(start_gpu);
	 
	// clock_t start = clock();
	matrixMultiplyTiled<<<grid, block>>>(c_A, c_B, c_C, N);
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
