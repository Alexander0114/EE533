// 3rd party lib for reading PNG files
#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv){
    char *image = argv[1];
		
    int width, height, channels;
    
    // image read using 3rd party funciton, input will be 1 channel array 
    unsigned char *imgData = stbi_load(image , &width, &height, &channels, 1);
    if (imgData == NULL) {
        printf("Image doesn't exist!\n");
        return 1;
    }

    char* extension = "_grey";
    strcat(image, extension);
    stbi_write_png(image , width, height, 1, imgData, width);
    printf("Saved processed image to output_edges.png\n");

    stbi_image_free(imgData);
}
