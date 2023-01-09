#!/bin/bash -l

# echo $@

ruby /app/stretcher.rb $@ > /app/input.jl

# cat /app/input.jl

/usr/local/julia/bin/julia -q -J/install/SysImage.so /app/input.jl > result

ruby /app/translate.rb result
