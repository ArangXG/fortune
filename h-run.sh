#!/usr/bin/env bash
# set -euo pipefail

cd `dirname $0`

# 读取静态路径（CUSTOM_CONFIG_FILENAME / CUSTOM_LOG_BASENAME 等）
. h-manifest.conf

# 读取 h-config.sh 生成的配置（含飞行表里的 CUSTOM_URL / CUSTOM_TEMPLATE / CUSTOM_USER_CONFIG）
[[ -f $CUSTOM_CONFIG_FILENAME ]] && . $CUSTOM_CONFIG_FILENAME

# 展开 CUSTOM_USER_CONFIG（例如取出 TOKEN）
EXPANDED_USER_CONFIG=$(eval echo "$CUSTOM_USER_CONFIG")
# set -a：把其中的 KEY=VALUE 全部自动 export，让 miner 子进程能读到（如 MINER_SUBMIT_VERSION）
set -a
eval "$CUSTOM_USER_CONFIG"
set +a

log() { printf '[%(%F %T)T] [select-miner] %s\n' -1 "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

echo "Debug CUSTOM_URL=$CUSTOM_URL CUSTOM_TEMPLATE=$CUSTOM_TEMPLATE TOKEN=$TOKEN MINER_SUBMIT_VERSION=$MINER_SUBMIT_VERSION"
echo "Debug MINER_SUBMIT_VERSION=$MINER_SUBMIT_VERSION"

## ───────────────────────────────────────────────
## 按 GPU 型号选 miner 二进制
## 检测失败一律 fallback 到 ./miner，不阻断启动
## ───────────────────────────────────────────────
MINER_BIN=./miner   # 安全默认

if ! command -v nvidia-smi >/dev/null 2>&1; then
    log "WARN: nvidia-smi not found; using default miner"
elif ! gpu_names="$(timeout 5 nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null)" \
     || [ -z "$gpu_names" ]; then
    log "WARN: nvidia-smi query failed or 0 GPUs (driver/掉卡?); using default miner"
else
    gpu_count=$(printf '%s\n' "$gpu_names" | grep -c .)
    five090_count=$(printf '%s\n' "$gpu_names" | grep -ic '5090' || true)
    five4060_count=$(printf '%s\n' "$gpu_names" | grep -ic '4060' || true)
    log "detected ${gpu_count} GPU(s): $(printf '%s\n' "$gpu_names" | paste -sd ';' -)"
    # ## 给 5090 使用独立二进制
    # if [ "$five090_count" -gt 0 ]; then
    #     [ "$five090_count" -eq "$gpu_count" ] \
    #         || log "WARN: mixed GPUs (${five090_count}/${gpu_count} are 5090); using miner-5090"
    #     MINER_BIN=./miner-5090
    # fi

    ## 给 4060 指定环境变量
    if [ "$five4060_count" -gt 0 ]; then
        export MINER_GPU_LARGE_SLOTS=1
    fi
fi

# 二进制本身缺失才算 fatal
[ -f "$MINER_BIN" ] || die "binary not found: $MINER_BIN"
[ -x "$MINER_BIN" ] || die "binary not executable: $MINER_BIN"

log "exec: $MINER_BIN"

## ───────────────────────────────────────────────
## 启动 miner
## 输出同时写入 HiveOS 标准日志（$CUSTOM_LOG_BASENAME.log），供 h-stats.sh 解析
## ───────────────────────────────────────────────
# --token 是可选项；TOKEN 为空时不传，避免传入空值导致 enrollment 失败
args=( --proxy "${CUSTOM_URL}" --address "${CUSTOM_TEMPLATE}" )
[[ -n "$TOKEN" ]] && args+=( --token "${TOKEN}" )
args+=( -gpu )

echo "Debug exec: $MINER_BIN ${args[*]}"

"$MINER_BIN" "${args[@]}" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
