#include <torch/serialize/tensor.h>
#include <torch/extension.h>

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


void roipool3dLauncher(int batch_size, int pts_num, int boxes_num, int feature_in_len, int sampled_pts_num,
                       const float *xyz, const float *boxes3d, const float *pts_feature, float *pooled_features, int *pooled_empty_flag);


int roipool3d_gpu(at::Tensor xyz, at::Tensor boxes3d, at::Tensor pts_feature, at::Tensor pooled_features, at::Tensor pooled_empty_flag){
    // params xyz: (B, N, 3)
    // params boxes3d: (B, M, 7)
    // params pts_feature: (B, N, C)
    // params pooled_features: (B, M, 512, 3+C)
    // params pooled_empty_flag: (B, M)
    CHECK_INPUT(xyz);
    CHECK_INPUT(boxes3d);
    CHECK_INPUT(pts_feature);
    CHECK_INPUT(pooled_features);
    CHECK_INPUT(pooled_empty_flag);

    int batch_size = xyz.size(0);
    int pts_num = xyz.size(1);
    int boxes_num = boxes3d.size(1);
    int feature_in_len = pts_feature.size(2);
    int sampled_pts_num = pooled_features.size(2);


    const float * xyz_data = xyz.data_ptr<float>();
    const float * boxes3d_data = boxes3d.data_ptr<float>();
    const float * pts_feature_data = pts_feature.data_ptr<float>();
    float * pooled_features_data = pooled_features.data_ptr<float>();
    int * pooled_empty_flag_data = pooled_empty_flag.data_ptr<int>();

    roipool3dLauncher(batch_size, pts_num, boxes_num, feature_in_len, sampled_pts_num,
                       xyz_data, boxes3d_data, pts_feature_data, pooled_features_data, pooled_empty_flag_data);



    return 1;
}


PYBIND11_MODULE(TORCH_EXTENSION_NAME, m) {
    m.def("forward", &roipool3d_gpu, "roipool3d forward (CUDA)");
}

