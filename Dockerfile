FROM gcr.io/bazel-public/bazel:5.4.1 AS builder

USER root
RUN set -ex \
 && apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
      libnetfilter-conntrack-dev

WORKDIR /src
ADD . /src/

RUN sed -i \
    -e 's|prometheus-cpp-master|prometheus-cpp-1.1.0|g' \
    -e 's|https://github.com/jupp0r/prometheus-cpp/archive/master.zip|https://github.com/jupp0r/prometheus-cpp/archive/refs/tags/v1.1.0.zip|g' \
    -e '/name = "com_github_jupp0r_prometheus_cpp"/,/^)/ s/sha256 *= *".*"/sha256 = ""/' \
    WORKSPACE

FROM builder AS build_debug
RUN bazel build -c dbg \
    --cxxopt='-std=c++17' --host_cxxopt='-std=c++17' \
    //:conntrack_exporter

FROM builder AS build_release
RUN bazel build --strip=always -c opt \
    --cxxopt='-std=c++17' --host_cxxopt='-std=c++17' \
    //:conntrack_exporter

FROM ubuntu:22.04 AS base
RUN set -ex \
 && apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends \
      libnetfilter-conntrack-dev
ENTRYPOINT ["conntrack_exporter"]

FROM base AS debug
COPY --from=build_debug /src/bazel-bin/conntrack_exporter /bin/

FROM base AS release
COPY --from=build_release /src/bazel-bin/conntrack_exporter /bin/

