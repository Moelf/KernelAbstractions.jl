using KernelAbstractions
using CUDA
using CUDAKernels
using AMDGPU
using ROCKernels
using Test

@kernel function copy_kernel!(A, @Const(B))
    I = @index(Global)
    @inbounds A[I] = B[I]
end

function mycopy!(A::Array, B::Array)
    @assert size(A) == size(B)
    kernel = copy_kernel!(CPU(), 8)
    kernel(A, B, ndrange=length(A))
end

A = zeros(128, 128)
B = ones(128, 128)
event = mycopy!(A, B)
wait(event)
@test A == B


if has_cuda_gpu()

    function mycopy!(A::CuArray, B::CuArray)
        @assert size(A) == size(B)
        copy_kernel!(CUDADevice(), 256)(A, B, ndrange=length(A))
    end

    A = CuArray{Float32}(undef, 1024)
    B = CUDA.ones(Float32, 1024)
    event = mycopy!(A, B)
    wait(event)
    @test A == B
end

function has_rocm_gpu()
    for agent in AMDGPU.get_agents()
        if agent.type == :gpu
            return true
        end
    end
    return false
end

if has_rocm_gpu()

    function mycopy!(A::ROCArray, B::ROCArray)
        @assert size(A) == size(B)
        copy_kernel!(ROCDevice(), 256)(A, B, ndrange=length(A))
    end

    A = zeros(Float32, 1024) |> ROCArray
    B = ones(Float32, 1024) |> ROCArray
    event = mycopy!(A, B)
    wait(event)
    @test A == B
end
