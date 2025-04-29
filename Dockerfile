# docker build -t mpas:8.2.2 .
# docker run --gpus all -it --entrypoint bash mpas:8.2.2
# docker run --gpus all -it --entrypoint bash --rm mpas:8.2.2
# docker exec -i -t <container_name> bash

# Base: LNCC / NVIDIA HPC SDK
FROM nvcr.io/nvidia/nvhpc:24.9-devel-cuda12.6-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# Instalar pacotes básicos
RUN apt update -y && apt upgrade -y && apt install -y \
    build-essential \
    curl \
    git \
    libbsd-dev \
    python3 \
    cmake \
    make \
    pkg-config \
    vim \
    environment-modules \
    m4 \
    perl \
    bzip2 \
    wget

# Variáveis de compilação
ENV NUM_PROCS=8
ENV CC=mpicc
ENV FC=mpif90
ENV CPP=cpp

# Criar usuário
RUN adduser --disabled-password --gecos "" monan
USER monan
WORKDIR /home/monan

# Baixar Spack
RUN wget https://github.com/spack/spack/releases/download/v0.23.1/spack-0.23.1.tar.gz && \
    tar zxvf spack-0.23.1.tar.gz

# Clonar o repositório
RUN git clone --single-branch --branch branch_v8.2.2 \
    https://github.com/TempoHPC/MPAS-Model.git MPAS-Model_v8.2.2_tempohpc

# Configurar ambiente e instalar dependências
RUN bash -c " \
    cd && \
    echo \$USER && echo \$HOME && \
    source /usr/share/modules/init/bash && \
    module use /opt/nvidia/hpc_sdk/modulefiles && \
    module load nvhpc-openmpi3/24.9 && \
    source spack-0.23.1/share/spack/setup-env.sh && \
    source ./MPAS-Model_v8.2.2_tempohpc/docker/nvhpc_24.9/env.sh && \
    source ./MPAS-Model_v8.2.2_tempohpc/docker/nvhpc_24.9/install.sh \
"

# Compilar o MPAS
WORKDIR /home/monan/MPAS-Model_v8.2.2_tempohpc
RUN make CORE=atmosphere clean && \
    bash docker/nvhpc_24.9/make.sh

# Baixar o benchmark
WORKDIR /home/monan
RUN wget https://www2.mmm.ucar.edu/projects/mpas/benchmark/v7.0/MPAS-A_benchmark_120km_v7.0.tar.gz && \
    tar -xvzf MPAS-A_benchmark_120km_v7.0.tar.gz

    
# Criar links simbólicos
WORKDIR /home/monan/MPAS-A_benchmark_120km_v7.0
RUN for file in CAM_ABS_DATA.DBL CAM_AEROPT_DATA.DBL GENPARM.TBL LANDUSE.TBL NoahmpTable.TBL \
                OZONE_DAT.DBL OZONE_LAT.TBL OZONE_PLEV.TBL OZONE_TBL \
                RRTMG_LW_DATA RRTMG_LW_DATA.DBL RRTMG_SW_DATA RRTMG_SW_DATA.DBL \
                SOILPARM.TBL VEGPARM.TBL atmosphere_model; do \
        if [ -e "/home/monan/MPAS-Model_v8.2.2_tempohpc/$file" ]; then \
            ln -sf "/home/monan/MPAS-Model_v8.2.2_tempohpc/$file" .; \
        else \
            echo "Arquivo $file não encontrado, ignorando..."; \
        fi; \
    done

# Entrypoint padrão
WORKDIR /home/monan/MPAS-A_benchmark_120km_v7.0
ENTRYPOINT ["/bin/bash"]
