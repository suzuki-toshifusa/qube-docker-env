#!/usr/bin/env bash
set -euo pipefail

# 概要:
#   MySQL general.log を JSONL に変換し、qube で再生します。
#   既定では "読み取り専用（SELECT/SHOW系）" での再生。
#
# 使い方（qube コンテナの中 or docker compose exec 経由）:
#   ./scripts/replay_from_general_log.sh [--full] [--nagents N] [--time DURATION] [--rate RATE] [--out FILE]
#
# 例:
#   # 読み取り専用で 60秒・並列20・QPS 500/s
#   ./scripts/replay_from_general_log.sh --nagents 20 --time 60s --rate 500/s
#
#   # ログをそのまま（INSERT/UPDATE/DELETE 含む）再生
#   ./scripts/replay_from_general_log.sh --full --time 30s
#
#   # 変換結果を out/queries.jsonl に保存してから再生
#   ./scripts/replay_from_general_log.sh --out /out/queries.jsonl

GENERAL_LOG="${GENERAL_LOG:-/logs/general.log}"
OUT_FILE="/out/readonly.jsonl"   # 既定の出力
MODE="readonly"                  # readonly | full
NAGENTS="${NAGENTS:-10}"
DURATION="${DURATION:-30s}"
RATE="${RATE:-}"                 # 例 "500/s"
KEY="Argument"

# DSN: env から拾う（compose 既定: root:pass@tcp(db:3306)/test）
DSN_DEFAULT='root:pass@tcp(db:3306)/test'
DSN="${DSN:-$DSN_DEFAULT}"

usage() {
  cat <<EOF
Usage: $0 [--full] [--nagents N] [--time DURATION] [--rate RATE] [--out FILE]

Options:
  --full            general.log をそのまま再生（INSERT/UPDATE/DELETE 含む）
  --nagents N       並列エージェント数（デフォルト: $NAGENTS）
  --time DURATION   実行時間（例: 30s, 1m）デフォルト: $DURATION
  --rate RATE       QPS 制限（例: 500/s）未指定なら制限なし
  --out FILE        変換後 JSONL の保存先（デフォルト: $OUT_FILE）
  -h, --help        このヘルプ

環境変数:
  DSN               DB 接続文字列（デフォルト: $DSN_DEFAULT）
  GENERAL_LOG       general.log のパス（デフォルト: $GENERAL_LOG）

EOF
}

# 引数パース
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) MODE="full"; shift ;;
    --nagents) NAGENTS="$2"; shift 2 ;;
    --time) DURATION="$2"; shift 2 ;;
    --rate) RATE="$2"; shift 2 ;;
    --out) OUT_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERROR] Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# チェック
if [[ ! -r "$GENERAL_LOG" ]]; then
  echo "[ERROR] GENERAL_LOG not found or unreadable: $GENERAL_LOG" >&2
  echo "       MySQL 側で general_log=ON になっているか、ログ出力先を確認してください。" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_FILE")"

echo "[INFO] Converting general log -> JSONL ($MODE) ..."
if [[ "$MODE" == "readonly" ]]; then
  # SELECT/SHOW 系だけを残す
  genlog "$GENERAL_LOG" | jq -c 'select(.Command=="Query") | select(.Argument|test("^(SELECT|SHOW)"; "i"))' > "$OUT_FILE"
else
  # そのまま（Query のみ）を残す
  genlog "$GENERAL_LOG" | jq -c 'select(.Command=="Query")' > "$OUT_FILE"
fi
echo "[INFO] Wrote: $OUT_FILE (lines: $(wc -l < "$OUT_FILE" | tr -d " "))"

# 直近の数行プレビュー
echo "[INFO] Preview:"
head -n 5 "$OUT_FILE" || true

# 再生
echo "[INFO] Replaying with qube ..."
set -x
if [[ -n "$RATE" ]]; then
  qube -f "$OUT_FILE" --key="$KEY" -d "$DSN" -n "$NAGENTS" -t "$DURATION" --rate "$RATE"
else
  qube -f "$OUT_FILE" --key="$KEY" -d "$DSN" -n "$NAGENTS" -t "$DURATION"
fi
set +x

echo "[INFO] Done."