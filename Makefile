.PONY: all


all:
	cmake -B abseil-cpp/build -DCMAKE_INSTALL_PATH=abseil-cpp/install -S abseil-cpp
	cmake --build abseil-cpp/build --target install -j
