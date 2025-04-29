# Base: LNCC / NVIDIA HPC SDK
FROM nvcr.io/nvidia/nvhpc:24.9-devel-cuda12.6-ubuntu22.04

# Ajustes iniciais
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

# Criar usuário monan
RUN adduser --disabled-password --gecos "" monan
USER monan
WORKDIR /home/monan

# Baixar Spack
RUN wget https://github.com/spack/spack/releases/download/v0.23.1/spack-0.23.1.tar.gz && \
    tar zxvf spack-0.23.1.tar.gz

# Baixar o código MPAS
RUN git clone --single-branch --branch branch_v8.2.2 \
    https://github.com/TempoHPC/MPAS-Model.git MPAS-Model_v8.2.2_tempohpc

# Configurar ambiente + instalar dependências via Spack
RUN bash -c " \
    source /usr/share/modules/init/bash && \
    module use /opt/nvidia/hpc_sdk/modulefiles && \
    module load nvhpc-openmpi3/24.9 && \
    source spack-0.23.1/share/spack/setup-env.sh && \
    spack compiler find && \
    spack external find m4 && \
    spack external find perl && \
    spack external find cmake && \
    spack external find bzip2 && \
    spack external find openmpi && \
    spack install parallelio%nvhpc@=24.9 ^parallel-netcdf ^netcdf-c@4.9.2~blosc~zstd \
"

# Compilar o MPAS
WORKDIR /home/monan/MPAS-Model_v8.2.2_tempohpc
RUN git pull && \
    make CORE=atmosphere clean && \
    bash docker/nvhpc_24.9/make.sh

# Repetir as etapas diretamente do install.sh
WORKDIR /home/monan/MPAS-Model_v8.2.2_tempohpc/docker/nvhpc_24.9
RUN bash -c " \
    source /usr/share/modules/init/bash && \
    module use /opt/nvidia/hpc_sdk/modulefiles && \
    module load nvhpc-openmpi3/24.9 && \
    source /home/monan/spack-0.23.1/share/spack/setup-env.sh && \
    spack compiler find && \
    spack external find m4 && \
    spack external find perl && \
    spack external find cmake && \
    spack external find openmpi && \
    spack external find bzip2 && \
    spack install parallelio%nvhpc@=24.9 ^parallel-netcdf ^netcdf-c@4.9.2~blosc~zstd \
"

# Baixar o benchmark
WORKDIR /home/monan
RUN wget https://www2.mmm.ucar.edu/projects/mpas/benchmark/v7.0/MPAS-A_benchmark_120km_v7.0.tar.gz && \
    tar -xvzf MPAS-A_benchmark_120km_v7.0.tar.gz

# Criar links simbólicos dos arquivos necessários no benchmark
WORKDIR /home/monan/MPAS-A_benchmark_120km_v7.0
RUN ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/CAM_ABS_DATA.DBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/CAM_AEROPT_DATA.DBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/GENPARM.TBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/LANDUSE.TBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/NoahmpTable.TBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/OZONE_DAT.DBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/OZONE_LAT.TBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/OZONE_PLEV.TBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/OZONE_TBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/RRTMG_LW_DATA . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/RRTMG_LW_DATA.DBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/RRTMG_SW_DATA . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/RRTMG_SW_DATA.DBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/SOILPARM.TBL . && \
    ln -s /home/monan/MPAS-Model_v8.2.2_tempohpc/VEGPARM.TBL .
