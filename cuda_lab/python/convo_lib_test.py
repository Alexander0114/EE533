import ctypes
import numpy as np
import time
from PIL import Image
import sys
# Load shared library
lib = ctypes.cdll.LoadLibrary("./convolution_lib.dll")
# Define argument types
lib.run_laplacian_cuda.argtypes = [
    ctypes.POINTER(ctypes.c_ubyte),  # host_img
    ctypes.c_int,                   # W
    ctypes.c_int,                   # H
    ctypes.c_int,                   # N
    ctypes.POINTER(ctypes.c_ubyte)   # host_output
]
# Get image path from command line or use default
image = sys.argv[1] if len(sys.argv) > 1 else "kitten_2160p_gray.jpg"

# Load and preprocess image
img = Image.open(image).convert("L")  # Convert to grayscale
img_data = np.array(img, dtype=np.uint8)
H, W = img_data.shape
N = 3  # Filter size
output_data = np.zeros((H, W), dtype=np.uint8)
start = time.time()
lib.run_laplacian_cuda(
    img_data.ctypes.data_as(ctypes.POINTER(ctypes.c_ubyte)),
    W,
    H,
    N,
    output_data.ctypes.data_as(ctypes.POINTER(ctypes.c_ubyte))
)
end = time.time()
print(f"Python call to CUDA convolution library completed in {end - start:.4f} seconds")

token = image.split(".")
final_filename = f"{token[0]}_laplaican.{token[1]}"

# Save output image
output_img = Image.fromarray(output_data)
output_img.save(final_filename)