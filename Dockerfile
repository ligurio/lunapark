# Use the latest Ubuntu LTS release as the base image
FROM ubuntu:latest

# Set environment variables (optional)
ENV DEBIAN_FRONTEND=noninteractive

# Update package lists and install any necessary packages
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y bash
RUN apt-get install -y vim
RUN apt-get install -y make
RUN apt-get install -y cmake
RUN apt-get install -y clang
RUN apt-get install -y git
RUN apt-get install -y libicu-dev
RUN apt-get install -y libreadline8 libreadline-dev
RUN apt-get install -y luarocks
RUN apt-get install -y build-essential
RUN apt-get install -y zlib1g zlib1g-dev
RUN apt-get install -y openssl libssl-dev
RUN apt-get install -y liblzma-dev
RUN apt-get install -y screen

RUN git clone https://github.com/tarantool/tarantool.git
COPY conv.patch /conv.patch
COPY fuzzer.patch /fuzzer.patch
WORKDIR /tarantool
RUN CC=clang CXX=clang++ cmake -DCMAKE_BUILD_TYPE=Debug -DENABLE_FUZZER=ON -DENABLE_BACKTRACE=ON -DLUAJIT_ENABLE_GC64=ON .
WORKDIR /tarantool/third_party/luajit
RUN git apply /conv.patch
WORKDIR /tarantool
RUN git apply /fuzzer.patch
RUN make luaL_loadbuffer_fuzzer -j4

# Copy application files (if any)
COPY .screenrc /.screenrc

# Define the command to run when the container starts
CMD ["bash"]
