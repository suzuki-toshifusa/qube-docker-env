# qube-docker-env

[qube](https://github.com/winebarrel/qube) の動作検証用Dockerコンテナ環境です。

## 概要

qubeはデータベース負荷テストツールで、JSON Lines形式のクエリファイルを使用してMySQLやPostgreSQLに対する負荷テストを実行できます。このリポジトリは、qubeをDocker環境で簡単に試すための環境を提供します。

このコンテナ内では、docker-compose.ymlファイルの 環境変数 DSN に記載しています。

## 構成

```
.
├── docker-compose.yml   # Docker Compose設定
├── dockerfile           # qubeコンテナのDockerfile
├── conf/
│   └── my.cnf           # MySQL設定ファイル
└── work/
    ├── setup.sql        # テストデータベース初期化SQL
    ├── data.jsonl       # サンプルクエリファイル
    ├── error.jsonl      # エラー用サンプルクエリ
    ├── general.jsonl    # 一般クエリログサンプル
    └── scripts/
        └── run_queries.sh # クエリ実行スクリプト
```

## セットアップ

### 1. コンテナの起動

```bash
docker compose up -d
```

以下の2つのコンテナが起動します：
- `qube-db`: MySQL 8.0データベース
- `qube-cli`: qube実行環境（qubeとgenlogがインストール済み）

### 2. データベースの初期化

```bash
docker compose exec db mysql -uroot -ppass test < work/setup.sql
```

これにより以下のテーブルが作成されます：
- `users`: ユーザー情報（5件のサンプルデータ）
- `orders`: 注文情報（5件のサンプルデータ）

## 使い方

### DSN（Data Source Name）

qube が採用している形式は、基本的に Go の標準ライブラリ database/sql が利用する DSN 形式（MySQL ドライバ: go-sql-driver/mysql) に準拠しています。

```
[username[:password]]@protocol(address)/dbname?param=value
```

例
```
root:pass@tcp(db:3306)/test
```

### 基本的な負荷テスト

qubeコンテナに入ってテストを実行：

```bash
# コンテナに接続
docker compose exec qube bash

# 基本的な負荷テスト実行
qube -d "${DSN}" -f /work/data.jsonl -n 5 -t 10s

# オプション説明:
# -d: データベース接続文字列（環境変数DSNを使用）
# -f: クエリファイル
# -n: エージェント数（並列実行数）
# -t: 実行時間
```

### クエリファイルの作成

JSON Lines形式でクエリを記述します：

```jsonl
{"q":"SELECT * FROM users WHERE id = 1"}
{"q":"SELECT * FROM orders WHERE user_id = 1"}
{"q":"SELECT u.name, o.amount FROM users u JOIN orders o ON u.id = o.user_id"}
```

コメントも使用可能（`//`で始まる行）：

```jsonl
{"q":"SELECT * FROM users"}
//これはコメント
//{"q":"SELECT * FROM orders"}
{"q":"SELECT * FROM users WHERE city = 'Tokyo'"}
```

### 主要なオプション

```bash
# レート制限（QPS）を指定
qube -d "${DSN}" -f /work/data.jsonl -n 5 -r 1000 -t 10s

# プログレス表示
qube -d "${DSN}" -f /work/data.jsonl -n 5 -t 10s --progress

# ランダムスタート位置
qube -d "${DSN}" -f /work/data.jsonl -n 5 -t 10s --random

# ループ無効化（データを1回だけ実行）
qube -d "${DSN}" -f /work/data.jsonl -n 5 --no-loop -t 10s

# エラーで停止しない
qube -d "${DSN}" -f /work/data.jsonl -n 5 -t 10s --force

# カラー出力
qube -d "${DSN}" -f /work/data.jsonl -n 5 -t 10s --color
```

### MySQL General Logからクエリを抽出

このコンテナには[genlog](https://github.com/winebarrel/genlog)もインストールされています。

```bash
# General Logを有効化（dbコンテナ側）
docker compose exec db mysql -uroot -ppass -e "SET GLOBAL general_log = 'ON'"

# クエリを実行してログに記録
docker compose exec db mysql -uroot -ppass test -e "SELECT * FROM users"

# General LogをJSON Lines形式に変換（qubeコンテナ側）
docker compose exec qube genlog /logs/general.log | jq -c "select(.Command==\"Query\")" > work/general.jsonl

```

### 一般ログからクエリファイルを生成してテストするサンプル手順

```bash
# General Logを有効化（dbコンテナ側）
docker compose exec db mysql -uroot -ppass -e "SET GLOBAL general_log = 'ON'"
```

```bash
# ログが溜まるクエリを実行
docker compose exec db bash /work/scripts/run_queries.sh
```

```bash
# General Logを無効化（dbコンテナ側）
docker compose exec db mysql -uroot -ppass -e "SET GLOBAL general_log = 'OFF'"
```

```bash
# 一般ログをJSONLに変換
docker compose exec qube bash
genlog /logs/general.log | jq -c "select(.Command==\"Query\")" > general.jsonl
```

```bash
# テスト実施
qube -f /work/general.jsonl --key="Argument"  -d ${DSN} -n 5 -t 100s
```


## 出力結果

qubeは実行結果をJSON形式で出力します：

```json
{                           
  "ID": "4ca84ab5-eba8-4fdf-960e-9dc0320ce9f9",
  "StartedAt": "2025-10-23T13:47:12.551180176+09:00",
  "FinishedAt": "2025-10-23T13:48:52.553873542+09:00",
  "ElapsedTime": "1m40.00164842s",
  "Options": {
    "Force": false,
    "DataFiles": [
      "/work/general.jsonl"
    ],
    "Key": "Argument",
    "Loop": true,
    "Random": false,
    "CommitRate": 0,
    "DSN": "root:pass@tcp(db:3306)/test",
    "Driver": "mysql",
    "Noop": false,
    "IAMAuth": false,
    "Nagents": 5,
    "Rate": 0,
    "Time": "1m40s"
  },
  "GOMAXPROCS": 12,
  "QueryCount": 219323,
  "ErrorQueryCount": 0,
  "AvgQPS": 2193,
  "MaxQPS": 2626,
  "MinQPS": 1066,
  "MedianQPS": 2182,
  "Duration": {
    "Count": 219323,
    "Histogram": [
      {
        "13µs - 8.993ms": 212483
      },
      {
        "8.993ms - 17.973ms": 514
      },
      {
        "17.973ms - 26.953ms": 150
      },
      {
        "26.953ms - 35.934ms": 298
      },
      {
        "35.934ms - 44.914ms": 556
      },
      {
        "44.914ms - 53.894ms": 1442
      },
      {
        "53.894ms - 62.874ms": 2251
      },
      {
        "62.874ms - 71.855ms": 1281
      },
      {
        "71.855ms - 80.835ms": 305
      },
      {
        "80.835ms - 89.815ms": 43
      }
    ],
    "Rate": {
      "Second": 438.9795402437739
    },
    "Samples": 219323,
    "Time": {
      "Avg": "2.27801ms",
      "Cumulative": "8m19.620095912s",
      "HMean": "68.02µs",
      "Long5p": "35.009076ms",
      "Max": "89.815708ms",
      "Min": "13.125µs",
      "P50": "61.208µs",
      "P75": "754µs",
      "P95": "5.358583ms",
      "P99": "60.335291ms",
      "P999": "74.229458ms",
      "Range": "89.802583ms",
      "Short5p": "27.253µs",
      "StdDev": "9.493693ms"
    }
  }
}
```

主な指標：
- `QueryCount`: 実行したクエリ総数
- `ErrorQueryCount`: エラーが発生したクエリ数
- `AvgQPS`: 平均QPS
- `Duration.Time.P95/P99`: レスポンスタイムのパーセンタイル

## 環境変数

`docker-compose.yml`で以下の環境変数が設定されています：

### dbコンテナ
- `MYSQL_ROOT_PASSWORD`: rootパスワード（デフォルト: `pass`）
- `MYSQL_DATABASE`: データベース名（デフォルト: `test`）
- `TZ`: タイムゾーン（Asia/Tokyo）

### qubeコンテナ
- `DSN`: データベース接続文字列（デフォルト: `root:pass@tcp(db:3306)/test`）
- `TZ`: タイムゾーン（Asia/Tokyo）

## 参考リンク

- [qube公式リポジトリ](https://github.com/winebarrel/qube)
- [genlog（MySQL General Log変換ツール）](https://github.com/winebarrel/genlog)
- [poslog（PostgreSQL Log変換ツール）](https://github.com/winebarrel/poslog)
