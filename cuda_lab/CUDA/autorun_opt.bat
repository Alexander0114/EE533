@echo off

for %%N in (512 1024 2048 4096 8192) do (
    echo Running N=%%N
    matrix_opt_gpu.exe %%N
)

pause