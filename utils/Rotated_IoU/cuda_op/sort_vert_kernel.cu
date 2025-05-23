#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "cuda_utils.h"

#define MAX_NUM_VERT_IDX 9
#define INTERSECTION_OFFSET 8
#define EPSILON 1e-8

/*
compare normalized vertices (vertices around (0,0))
if vertex1 < vertex2 return ture.
order: minimum at x-aixs, become larger in anti-clockwise direction
*/
__device__ bool compare_vertices(float x1, float y1, float x2, float y2){

    if (fabs(x1-x2)<EPSILON && fabs(y2-y1)<EPSILON)
        return false;       // if equal, return false

    if (y1 > 0 &&  y2 < 0)
        return true;
    if (y1 < 0 && y2 > 0)
        return false;
    
    float n1 = x1*x1 + y1*y1 + EPSILON;
    float n2 = x2*x2 + y2*y2 + EPSILON;
    
    if (y1 > 0 && y2 > 0){
        if (fabs(x1)*x1/n1 - fabs(x2)*x2/n2 > EPSILON)
            return true;
        else 
            return false;   
    }
    if (y1 < 0 && y2 < 0) {
        if (fabs(x1)*x1/n1 - fabs(x2)*x2/n2 < EPSILON)
            return true;
        else 
            return false;
    }
}

__global__ void sort_vertices_kernel(int b, int n, int m,
                                    const float *__restrict__ vertices,
                                    const bool *__restrict__ mask,
                                    const int *__restrict__ num_valid,
                                    int *__restrict__ idx){
    int batch_idx = blockIdx.x;
    vertices += batch_idx * n * m *2;
    mask += batch_idx * n * m;
    num_valid += batch_idx * n;
    idx += batch_idx * n * MAX_NUM_VERT_IDX;
    
    int index = threadIdx.x;        // index of polygon
    int stride = blockDim.x;
    for (int i = index; i<n; i+=stride){
        int pad;    // index of arbitary invalid intersection point (not box corner!)
        for (int j=INTERSECTION_OFFSET; j<m; ++j){
            if (!mask[i*m + j]){
                pad = j;
                break;
            }
        }
        if (num_valid[i] < 3){
            // not enough vertices, take an invalid intersection point 
            // (zero padding)
            for (int j=0; j<MAX_NUM_VERT_IDX; ++j){
                idx[i*MAX_NUM_VERT_IDX + j] = pad;
            }
        } else {
            // sort the valid vertices
            // note the number of valid vertices is known
            for (int j=0; j<num_valid[i]; ++j){
                // initilize with a "big" value
                float x_min = 1;
                float y_min = -EPSILON;
                int i_take = 0;                
                for (int k=0; k<m; ++k){
                    float x = vertices[i*m*2 + k*2 + 0];
                    float y = vertices[i*m*2 + k*2 + 1];
                    if (j==0){
                        if (mask[i*m+k] && compare_vertices(x, y, x_min, y_min)){
                            x_min = x;
                            y_min = y;
                            i_take = k;
                        } 
                    } else {
                        int i2 = idx[i*MAX_NUM_VERT_IDX + j - 1];
                        float x2 = vertices[i*m*2 + i2*2 + 0];
                        float y2 = vertices[i*m*2 + i2*2 + 1];
                        if (mask[i*m+k] &&
                            compare_vertices(x, y, x_min, y_min) && 
                            compare_vertices(x2, y2, x, y)
                            ){
                            x_min = x;
                            y_min = y;
                            i_take = k;
                        } 
                    }
                    idx[i*MAX_NUM_VERT_IDX + j] = i_take;
                }
            }
            // duplicate the first idx
            idx[i*MAX_NUM_VERT_IDX + num_valid[i]] = idx[i*MAX_NUM_VERT_IDX + 0];

            // pad zeros
            for (int j=num_valid[i]+1; j<MAX_NUM_VERT_IDX; ++j){
                idx[i*MAX_NUM_VERT_IDX + j] = pad;
            }

            // for corner case: the two boxes are exactly the same.
            // in this case, idx would have duplicate elements, which makes the shoelace formula broken
            // because of the definition, the duplicate elements only appear in the first 8 positions
            // (they are "corners in box", not "intersection of edges")
            if (num_valid[i] == 8){
                int counter = 0;
                for (int j=0; j<4; ++j){
                    int check = idx[i*MAX_NUM_VERT_IDX + j];
                    for (int k=4; k<INTERSECTION_OFFSET; ++k){
                        if (idx[i*MAX_NUM_VERT_IDX + k] == check)
                            counter++;
                    }
                }
                if (counter == 4){
                    idx[i*MAX_NUM_VERT_IDX + 4] = idx[i*MAX_NUM_VERT_IDX + 0];
                    for (int j = 5; j<MAX_NUM_VERT_IDX; ++j){
                        idx[i*MAX_NUM_VERT_IDX + j] = pad;
                    }
                }                            
            }

            // TODO: still might need to cover some other corner cases :(
        }
    }
}

void sort_vertices_wrapper(int b, int n, int m,  const float *vertices, const bool *mask, const int *num_valid, int* idx){
    static cudaStream_t stream = at::cuda::getCurrentCUDAStream();
    sort_vertices_kernel<<<b, opt_n_thread(n)>>>(b, n, m, vertices, mask, num_valid, idx);
    CUDA_CHECK_ERRORS();
}