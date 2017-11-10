#include <iostream>
#include <fstream>
#include <sstream>
#include <tuple>
#include <vector>
#include <random>

#include <assert.h>

#include "convolve.cu"

const char *INPUT_FNAME  = "input.txt";
const char *OUTPUT_FNAME = "output.txt";

void read_from_fstream(std::ifstream &input, float *arr, const size_t size)
{
    float val;
    for(size_t i = 0; i < size; ++i)
    {
        for(size_t j = 0; j < size; ++j)
        {
            input >> val;
            arr[i*size + j] = val;
        }
    }
}

std::tuple<SquareMatrix, SquareMatrix> read_data(const char *fname)
{
    std::ifstream input_file(fname);

    if(!input_file.is_open())
    {
        std::cerr << "Cannot open " << fname << "!\n";
        exit(1);
    }

    size_t N, M;

    input_file >> N >> M;

    SquareMatrix A(N);
    SquareMatrix B(M);

    read_from_fstream(input_file, A.data(), N);
    read_from_fstream(input_file, B.data(), M);

    return std::make_tuple(A, B);
}

void print_matrix(const SquareMatrix &m)
{
    for(size_t i = 0; i < m.size(); ++i)
    {
        for(size_t j = 0; j < m.size(); ++j)
        {
            std::cout << m[i][j] << ' ';
        }
        std::cout << '\n';
    }
}


float calc_cell_convolve(const SquareMatrix &A, const SquareMatrix &B, int i, int j)
{
    float val = 0;
    int HM = (B.size() - 1)/2;

    for(int k = -HM; k <= HM; ++k)
    {
        for(int l = -HM; l <= HM; ++l)
        {
            val += A.get_val(i+k, j+l)*B.get_val(k+HM, l+HM);
        }
    }

    return val;
}


// simple function to check the result
SquareMatrix convolve(const SquareMatrix &A, const SquareMatrix &B)
{
    SquareMatrix C(A.size());

    for(size_t i = 0; i < A.size(); ++i)
    {
        for(size_t j = 0; j < A.size(); ++j)
        {
            C[i][j] = calc_cell_convolve(A, B, i, j);
        }
    }

    return C;
}


void write_data(const char *fname, const SquareMatrix &m)
{
    std::ofstream out_file(fname);

    if(!out_file.is_open())
    {        
        std::cerr << "Cannot open " << fname << "!\n";
        return;
    }    

    for(size_t i = 0; i < m.size(); ++i)
    {
        for(size_t j = 0; j < m.size(); ++j)
        {
            out_file << m[i][j] << ' ';
        }
        out_file << '\n';
    }
}

SquareMatrix generate_random_matrix(size_t sz)
{
    std::default_random_engine generator;
    std::normal_distribution<float> distribution(5.0,2.0);

    SquareMatrix m(sz);

    for(size_t i = 0; i < sz; ++i)
    {
        for(size_t j = 0; j < sz; ++j)
        {
            m[i][j] = distribution(generator);
        }   
    }

    return m;
}

void run_test()
{
    using test_val_t = std::tuple<SquareMatrix, SquareMatrix, const char *>;

    auto test_func = [](const SquareMatrix &A, const SquareMatrix &B)
                        {
                            SquareMatrix correct = convolve(A, B);
                            SquareMatrix cuda_res = convolve_with_cuda(A, B);

                            return correct == cuda_res;
                        };

    std::vector<test_val_t> test_vals = {
                                            std::make_tuple(SquareMatrix(5, 1.),    SquareMatrix(3, 1.), "1st"),
                                            std::make_tuple(SquareMatrix(1024, 1.), SquareMatrix(3, 1.), "2nd"),
                                            std::make_tuple(SquareMatrix(1024, 1.), SquareMatrix(9, 1.), "3rd"),
                                            std::make_tuple(SquareMatrix(1, 1.),    SquareMatrix(9, 1.), "4th"),
                                            std::make_tuple(SquareMatrix(31, 1.),   SquareMatrix(9, 1.), "5th"),
                                            std::make_tuple(SquareMatrix(1023, 1.), SquareMatrix(9, 1.), "6th"),

                                            std::make_tuple(generate_random_matrix(1000), generate_random_matrix(5), "7th")
                                        };

    for(const test_val_t &test : test_vals)
    {
        bool res = test_func(std::get<0>(test), std::get<1>(test));

        if(res)
        {
            std::cout << std::get<2>(test) << " is correct\n";
        }
        else
        {
            std::cout << std::get<2>(test) << " is incorrect\n";
            return;
        }
    }

    std::cout << "All tests passed!\n";
}


int main(int argc, char **argv)
{
    if(argc == 2 && strcmp(argv[1], "test") == 0)
    {
        run_test();
    }
    else
    {
        SquareMatrix A, B;
        std::tie(A, B) = read_data(INPUT_FNAME);

        SquareMatrix correct = convolve(A, B);
        SquareMatrix cuda_res = convolve_with_cuda(A, B);
        
        if(correct == cuda_res)
        {
            std::cout << "Ok!\n";
            
        }
        else
        {
            std::cout << "Error!\n";
        }

        write_data(OUTPUT_FNAME, cuda_res);
    }


    return 0;
}