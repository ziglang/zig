FROM debian:stable

RUN mkdir -p /app \
    && apt-get -y update \
    && apt-get install -y curl wget cmake build-essential \
    # install llvm, clang, ldd
    && wget https://apt.llvm.org/llvm.sh \
    && chmod +x llvm.sh \
    && ./llvm.sh 11 \
    && rm -rf ./llvm.sh \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN /bin/bash install.sh

CMD /bin/bash
