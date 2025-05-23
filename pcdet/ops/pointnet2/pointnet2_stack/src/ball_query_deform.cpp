#include <torch/serialize/tensor.h>
#include <vector>
#include <ATen/cuda/CUDAContext.h>
#include <ATen/cuda/CUDAEvent.h>
#include <cuda.h>
#include <cuda_runtime_api.h>
#include "ball_query_deform_gpu.h"

static cudaStream_t stream = at::cuda::getCurrentCUDAStream();

#define CHECK_CUDA(x) do { \
  if (!x.type().is_cuda()) { \
    fprintf(stderr, "%s must be CUDA tensor at %s:%d\n", #x, __FILE__, __LINE__); \
    exit(-1); \
  } \
} while (0)
#define CHECK_CONTIGUOUS(x) do { \
  if (!x.is_contiguous()) { \
    fprintf(stderr, "%s must be contiguous tensor at %s:%d\n", #x, __FILE__, __LINE__); \
    exit(-1); \
  } \
} while (0)
#define CHECK_INPUT(x) CHECK_CUDA(x);CHECK_CONTIGUOUS(x)

int ball_query_deform_wrapper_stack(int B, int M, int nsample,
    at::Tensor new_xyz_tensor, at::Tensor new_xyz_r_tensor, at::Tensor new_xyz_batch_cnt_tensor,
    at::Tensor xyz_tensor, at::Tensor xyz_batch_cnt_tensor, at::Tensor idx_tensor) {
    CHECK_INPUT(new_xyz_tensor);
    CHECK_INPUT(new_xyz_r_tensor);
    CHECK_INPUT(xyz_tensor);
    CHECK_INPUT(new_xyz_batch_cnt_tensor);
    CHECK_INPUT(xyz_batch_cnt_tensor);

    const float *new_xyz = new_xyz_tensor.data<float>();
    const float *new_xyz_r = new_xyz_r_tensor.data<float>();
    const float *xyz = xyz_tensor.data<float>();
    const int *new_xyz_batch_cnt = new_xyz_batch_cnt_tensor.data<int>();
    const int *xyz_batch_cnt = xyz_batch_cnt_tensor.data<int>();
    int *idx = idx_tensor.data<int>();

    ball_query_deform_kernel_launcher_stack(B, M, nsample, new_xyz, new_xyz_r, new_xyz_batch_cnt, xyz, xyz_batch_cnt, idx);
    return 1;
}