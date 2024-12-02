.PONY: all


all:
	cmake -B abseil-cpp/build -DCMAKE_INSTALL_PREFIX=./abseil-cpp/install/ -S abseil-cpp -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_C_COMPILER=clang
	cmake --build abseil-cpp/build --target install -j
