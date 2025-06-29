# First Stage: Builder
FROM mcr.microsoft.com/devcontainers/cpp:dev-ubuntu AS builder

# Enable deb-src and install system dependencies
RUN sed -i.bak "/^#.*deb-src.*universe$/s/^# //g" /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      software-properties-common \
      subversion \
      libmagick++-dev \
    && add-apt-repository --enable-source --yes "ppa:marutter/rrutter4.0" \
    && wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
    && apt-get update \
    && apt-get build-dep -y r-base-dev \
    && apt-get install -y r-base-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install R packages from r-universe
RUN Rscript -e "runiverse <- sprintf('r-universe.dev/bin/linux/%s-%s/%s/', \
                                 system2('lsb_release', '-sc', stdout = TRUE), \
                                 R.version\$arch, \
                                 substr(getRversion(), 1, 3)); \
                print('Installing packages...'); \
                install.packages(c('languageserver', 'httpgd'), \
                 repos = c(runiverse = paste0('https://cran.', runiverse), \
                           nx10 = paste0('https://nx10.', runiverse))); \
                print('Packages installed.')"

# Second Stage: Final Image
FROM mcr.microsoft.com/devcontainers/cpp:dev-ubuntu-22.04 AS final

ARG CONTAINER_VERSION
ENV CONTAINER_VERSION=${CONTAINER_VERSION}

# Install runtime dependencies for R
RUN apt-get update && apt-get install -y --no-install-recommends \
    libxml2 \
    libcurl4-openssl-dev \
    libssl-dev \
    libblas-dev \
    liblapack-dev \
    gfortran \
    libmagick++-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy R installation and libraries from builder stage
COPY --from=builder /usr/lib/R /usr/lib/R
COPY --from=builder /usr/local/lib/R /usr/local/lib/R
COPY --from=builder /usr/bin/R /usr/bin/R
COPY --from=builder /usr/share/R /usr/share/R
COPY --from=builder /etc/R /etc/R
COPY --from=builder /usr/lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu

# Environment variables for R
ENV PATH="/usr/lib/R/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/lib/R/lib:/usr/lib/x86_64-linux-gnu"

# Verify R installation
RUN ldconfig && R --version
