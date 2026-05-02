@echo off
setlocal enabledelayedexpansion

:: 1. Configuration
set min_n=3
set max_n=5
set filters=sobel laplacian sharpen
set images=kitten_226p_gray.png kitten_720p_gray.png kitten_2160p_gray.jpg

:: 2. Nested Loops
for %%i in (%images%) do (
    for %%f in (%filters%) do (
        for /L %%n in (%min_n%,1,%max_n%) do (
            echo ------------------------------------
            echo Image:  %%i
            echo Filter: %%f
            echo Size:   %%n

            convolution.exe %%n %%f %%i
        )
    )
)

echo.
echo Benchmarking Complete!
pause