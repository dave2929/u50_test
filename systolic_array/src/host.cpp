/**
* Copyright (C) 2019-2021 Xilinx, Inc
*
* Licensed under the Apache License, Version 2.0 (the "License"). You may
* not use this file except in compliance with the License. A copy of the
* License is located at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
* WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
* License for the specific language governing permissions and limitations
* under the License.
*/
#include "xcl2.hpp"
#include <vector>

#define DATA_SIZE 16

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cout << "Usage: " << argv[0] << " <XCLBIN File>" << std::endl;
        return EXIT_FAILURE;
    }

    std::string binaryFile = argv[1];

    cl_int err;
    cl::CommandQueue q;
    cl::Context context;
    cl::Kernel krnl_vadd;
    auto size = DATA_SIZE;
    // Allocate Memory in Host Memory
    auto vector_size_bytes = sizeof(__uint128_t) * size;
    std::vector<__uint128_t, aligned_allocator<__uint128_t> > source_input1(size);
    std::vector<__uint128_t, aligned_allocator<__uint128_t> > source_input2(size);
    std::vector<__uint128_t, aligned_allocator<__uint128_t> > source_hw_results(size);
    std::vector<__uint128_t, aligned_allocator<__uint128_t> > source_sw_results(size);

    // Create the test data and Software Result
    for (int i = 0; i < size; i++) {
        source_input1[i] = 0;
        source_input2[i] = 0;
        source_sw_results[i] = 0;
        source_hw_results[i] = 0;
    }

    source_input1[0] = 0b00000000000000000000000000000000000000000000000000000000111010001111100010111010111111001001111101110111110000111110110000100001;
    source_input1[1] = 0b00000000000000000000000000000000000000000000000000000000111100110001011001111000010111110010001001110111110010111111101000001110;
    source_input1[2] = 0b00000000000000000000000000000000000000000000000000000000000011101000001001000101011000100100000000100000000110000001011111110010;
    source_input1[3] = 0b00000000000000000000000000000000000000000000000000000000001001100111101000111100011000101001111110100000000101111111101111111101;
    source_input1[4] = 0b00000000000000000000000000000000000000000000000000000000001111001001111010111110000001111111000101110111001110001100000000101001;
    source_input1[5] = 0b00000000000000000000000000000000000000000000000000000000000111011111100111000101001000101001000000100000010010000100111111101100;
    source_input1[6] = 0b00000000000000000000000000000000000000000000000000000000110110110000010101000011001111011110000001010111111011000000111111111111;
    source_input1[7] = 0b00000000000000000000000000000000000000000000000000000000111001111111111100111101010111101110111111011001010100001000011000001001;
    source_input1[8] = 0b00000000000000000000000000000000000000000000000000000000111101010111100101111101111111101011111101010111101101111101011111101101;
    source_input1[9] = 0b00000000000000000000000000000000000000000000000000000000111110101111101111111110110111110010111101111111110100111110000111101101;
    source_input1[10] = 0b00000000000000000000000000000000000000000000000000000000111111000111110110111110011111111000111110110111110100111110111111110100;
    source_input1[11] = 0b00000000000000000000000000000000000000000000000000000000111101111111110100111101011111101111111110011111101011111101111111110100;
    source_input1[12] = 0b00000000000000000000000000000000000000000000000000000000111101111111101101111110001111101101111101011111110010111101110111101011;
    source_input1[13] = 0b00000000000000000000000000000000000000000000000000000000111110110111110011111110111111110101111110001111110111111110100111110010;
    source_input1[14] = 0b00000000000000000000000000000000000000000000000000000000111110100111111000111101111111110010111110111111101110111110010111110111;
    source_input1[15] = 0b00000000000000000000000000000000000000000000000000000000111101111111110000111110010111101110111101111111110001111101111111101110;

    // OPENCL HOST CODE AREA START
    // Create Program and Kernel
    auto devices = xcl::get_xil_devices();

    // read_binary_file() is a utility API which will load the binaryFile
    // and will return the pointer to file buffer.
    auto fileBuf = xcl::read_binary_file(binaryFile);
    cl::Program::Binaries bins{{fileBuf.data(), fileBuf.size()}};
    bool valid_device = false;
    for (unsigned int i = 0; i < devices.size(); i++) {
        auto device = devices[i];
        // Creating Context and Command Queue for selected Device
        OCL_CHECK(err, context = cl::Context(device, nullptr, nullptr, nullptr, &err));
        OCL_CHECK(err, q = cl::CommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &err));

        std::cout << "Trying to program device[" << i << "]: " << device.getInfo<CL_DEVICE_NAME>() << std::endl;
        cl::Program program(context, {device}, bins, nullptr, &err);
        if (err != CL_SUCCESS) {
            std::cout << "Failed to program device[" << i << "] with xclbin file!\n";
        } else {
            std::cout << "Device[" << i << "]: program successful!\n";
            OCL_CHECK(err, krnl_vadd = cl::Kernel(program, "krnl_vadd_rtl", &err));
            valid_device = true;
            break; // we break because we found a valid device
        }
    }
    if (!valid_device) {
        std::cout << "Failed to program any device found, exit!\n";
        exit(EXIT_FAILURE);
    }

    // Allocate Buffer in Global Memory
    OCL_CHECK(err, cl::Buffer buffer_r1(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY, vector_size_bytes,
                                        source_input1.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_r2(context, CL_MEM_USE_HOST_PTR | CL_MEM_READ_ONLY, vector_size_bytes,
                                        source_input2.data(), &err));
    OCL_CHECK(err, cl::Buffer buffer_w(context, CL_MEM_USE_HOST_PTR | CL_MEM_WRITE_ONLY, vector_size_bytes,
                                       source_hw_results.data(), &err));

    // Set the Kernel Arguments
    OCL_CHECK(err, err = krnl_vadd.setArg(0, buffer_r1));
    OCL_CHECK(err, err = krnl_vadd.setArg(1, buffer_r2));
    OCL_CHECK(err, err = krnl_vadd.setArg(2, buffer_w));
    OCL_CHECK(err, err = krnl_vadd.setArg(3, size));

    // Copy input data to device global memory
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_r1, buffer_r2}, 0 /* 0 means from host*/));

    // Launch the Kernel
    OCL_CHECK(err, err = q.enqueueTask(krnl_vadd));

    // Copy Result from Device Global Memory to Host Local Memory
    OCL_CHECK(err, err = q.enqueueMigrateMemObjects({buffer_w}, CL_MIGRATE_MEM_OBJECT_HOST));
    OCL_CHECK(err, err = q.finish());

    // OPENCL HOST CODE AREA END

    // Compare the results of the Device to the simulation
    int match = 0;
    for (int i = 0; i < size; i++) {
        printf("i = %d Device result = %x\n", i, source_hw_results[i]);
    }

    std::cout << "TEST " << (match ? "FAILED" : "PASSED") << std::endl;
    return (match ? EXIT_FAILURE : EXIT_SUCCESS);
}
