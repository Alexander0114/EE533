#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <cuda_runtime.h>
#include <cublas_v2.h>
//#define TILE_WIDTH 16

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

    cublasHandle_t handle;
    cublasCreate(&handle);

    float alpha = 1.0f;
    float beta  = 0.0f;



    // GPU timing, as previous timing seems odd
    cudaEvent_t start_gpu, stop_gpu;
    cudaEventCreate(&start_gpu);
    cudaEventCreate(&stop_gpu);

    cudaEventRecord(start_gpu);
	 
    cublasSgemm(
        handle,
        CUBLAS_OP_N, CUBLAS_OP_N,
        N, N, N,
        &alpha,
        c_B, N,
        c_A, N,
        &beta,
        c_C, N
    );

    cudaDeviceSynchronize();
    cudaMemcpy(C, c_C, size, cudaMemcpyDeviceToHost);

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
