# ─── Amazon Linux 2023 Production Container ──────────────
# Base image for running applications on AL2023
# Registry: public.ecr.aws/amazonlinux/amazonlinux

FROM public.ecr.aws/amazonlinux/amazonlinux:2023 AS base

# Install common runtime dependencies
RUN dnf update -y && \
    dnf install -y \
      python3 \
      python3-pip \
      aws-cli-2 \
      shadow-utils \
      procps-ng \
      tar \
      gzip \
      curl \
      jq && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create non-root user
RUN useradd -m -s /bin/bash -u 1000 appuser

# ─── Builder Stage (for compiled apps) ───────────────────
FROM base AS builder

RUN dnf install -y \
      gcc \
      gcc-c++ \
      make \
      cmake \
      git && \
    dnf clean all

WORKDIR /build
# COPY . .
# RUN make build

# ─── Production Stage ────────────────────────────────────
FROM base AS production

WORKDIR /app

# Copy application files
# COPY --from=builder /build/output ./

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080

CMD ["/bin/bash"]
