// 3rd party lib for reading PNG files
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// convolution fucntion
unsigned char* convolve(unsigned char* img, int W, int H, int* filter, int N) {
    // image size will be shrinked after convolution
    int outW = W - N + 1;
    int outH = H - N + 1;

    // Allocate memory for the output image
    unsigned char* output = (unsigned char*)malloc(outW * outH * sizeof(unsigned char));
    if (!output) return NULL;

    for (int y = 0; y < outH; y++) {
        for (int x = 0; x < outW; x++) {
            long sum = 0;

            for (int ky = 0; ky < N; ky++) {
                for (int kx = 0; kx < N; kx++) {
                    int pixelIndex = (y + ky) * W + (x + kx);
                    sum += img[pixelIndex] * filter[ky * N + kx];
                }
            }

            // Clamp the value to 0-255 range
            if (sum < 0) sum = 0;
            if (sum > 255) sum = 255;

            output[y * outW + x] = (unsigned char)sum;
        }
    }
    return output;
}

int main(int argc, char** argv) {
    if (argc < 4) {
	    printf("Enter filter size from 3 to 5, filter to use(sobel, laplachian, sharpen), and image file name!\n");
	    return 1;
    }

    int N = atoi(argv[1]);
    char *image = argv[3];
    char *filter_name = argv[2];
    int *filter = NULL;

    int sobel3[9] = {
        -1, 0, 1,
        -2, 0, 2,
        -1, 0, 1
    };

    int sobel4[16] = {
	-1, -2, 2, 1,
	-3, -6, 6, 3,
	-3, -6, 6, 3,
	-1, -2, 2, 1,
    };

    int sobel5[25] = {
        -1, -2, 0, 2, 1,
	-4, -8, 0, 8, 4,
	-6,-12, 0, 12, 6,
	-4, -8, 0, 8, 4,
	-1, -2, 0, 2, 1,
    };


    int laplacian3[9] = {
    0,  1,  0,
    1, -4,  1,
    0,  1,  0
    };

    int laplacian4[16] = {
    0,  1,  1,  0,
    1, -2, -2,  1,
    1, -2, -2,  1,
    0,  1,  1,  0
    };

    int laplacian5[25] = {
    0,  0, -1,  0,  0,
    0, -1, -2, -1,  0,
   -1, -2, 16, -2, -1,
    0, -1, -2, -1,  0,
    0,  0, -1,  0,  0
    };

    int sharpen3[9] = {
     0, -1,  0,
    -1,  5, -1,
     0, -1,  0
    };

    int sharpen4[16] = {
    -1, -1, -1, -1,
    -1,  9,  9, -1,
    -1,  9,  9, -1,
    -1, -1, -1, -1
    };

    int sharpen5[25] = {
    -1, -1, -1, -1, -1,
    -1,  2,  2,  2, -1,
    -1,  2,  8,  2, -1,
    -1,  2,  2,  2, -1,
    -1, -1, -1, -1, -1
    };

    if(strcmp(filter_name, "sobel") == 0) {
    	if(N == 3) filter = sobel3;
    	else if (N == 4) filter = sobel4;
    	else if (N == 5) filter = sobel5;
    	else {
    	    printf("Only support size from 3 to 5\n");
    	    return 1;
    	}
    } else if(strcmp(filter_name, "laplacian") == 0) {
    	if(N == 3) filter = laplacian3;
    	else if (N == 4) filter = laplacian4;
    	else if (N == 5) filter = laplacian5;
    	else {
    	    printf("Only support size from 3 to 5\n");
    	    return 1;
    	}
    } else if(strcmp(filter_name, "sharpen") == 0) {
    	if(N == 3) filter = sharpen3;
    	else if (N == 4) filter = sharpen4;
    	else if (N == 5) filter = sharpen5;
    	else {
    	    printf("Only support size from 3 to 5\n");
    	    return 1;
        }
    } else {
        printf("We don't support the filter you want!\n");
        return 1;
    }

    int width, height, channels;
    
    // image read using 3rd party funciton, input will be 1 channel array 
    unsigned char *imgData = stbi_load(image , &width, &height, &channels, 1);
    if (imgData == NULL) {
        printf("Image doesn't exist!\n");
        return 1;
    }
    

    clock_t start = clock();
    unsigned char *result = convolve(imgData, width, height, filter, N);
    clock_t end = clock();

    double elapsed = (double)(end - start) / CLOCKS_PER_SEC;
    printf("CPU execution time: %f seconds\n", elapsed);
    
    if (result) {
        int outW = width - N + 1;
        int outH = height - N + 1;
	char file_name[256];
        char base_name[128];
	strcpy(base_name, image);
	char *dot = strrchr(base_name, '.');
	if (dot) *dot = '\0';

	sprintf(file_name, "%s_%s.png", base_name, filter_name);

        stbi_write_png(file_name, outW, outH, 1, result, outW);
        printf("Saved processed image to %s\n", file_name);

        free(result);
    }

    stbi_image_free(imgData);
    return 0;
}
