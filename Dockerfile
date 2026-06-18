FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libgomp1 \
    ca-certificates \
    libnuma1 \
    && rm -rf /var/lib/apt/lists/*

COPY miner /usr/local/bin/miner
RUN chmod +x /usr/local/bin/miner

# ── GPU Mining · PearlFortune · Pearl ───────────────────────────
ENV PROXY=global.pearlfortune.org:443
ENV PRL_ADDRESS=your-prl-address-here
ENV WORKER=

CMD nvidia-smi -q -d POWER && \
    /usr/local/bin/miner \
    --proxy ${PROXY} \
    --address ${PRL_ADDRESS} \
    --worker ${WORKER:-$(hostname)} \
    -gpu
