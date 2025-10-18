#!/bin/bash
set -e

MYSQL="mysql -h db -uroot -ppass test -N -B -e"

echo "[INFO] Running test queries..."

# Enable general log to capture all queries
$MYSQL "SET GLOBAL general_log = ON;"

# 1. SELECT系
$MYSQL "SELECT * FROM users LIMIT 3;"
$MYSQL "SELECT name, city FROM users WHERE age > 30;"
$MYSQL "SELECT COUNT(*), city FROM users GROUP BY city;"
$MYSQL "SELECT u.name, o.amount FROM users u JOIN orders o ON u.id=o.user_id WHERE o.status='paid';"

# 2. INSERT系
$MYSQL "INSERT INTO users (name, age, city) VALUES ('Frank', 29, 'Kyoto');"
$MYSQL "INSERT INTO orders (user_id, amount, status) VALUES (6, 180.25, 'pending');"

# 3. UPDATE系
$MYSQL "UPDATE users SET age = age + 1 WHERE city='Tokyo';"
$MYSQL "UPDATE orders SET status='paid' WHERE id=2;"

# 4. DELETE系
$MYSQL "DELETE FROM orders WHERE status='cancelled';"

# 5. 複雑なSELECT（集約、結合、ソート）
$MYSQL "SELECT u.name, COUNT(o.id) AS order_count, SUM(o.amount) AS total_amount
        FROM users u LEFT JOIN orders o ON u.id=o.user_id
        GROUP BY u.id ORDER BY total_amount DESC LIMIT 5;"

# 6. サブクエリ
$MYSQL "SELECT name FROM users WHERE id IN (SELECT user_id FROM orders WHERE amount > 200);"

# 7. プレースホルダっぽい文字列（負荷再生確認用）
for i in {1..5}; do
  $MYSQL "SELECT * FROM users WHERE id = $i;"
done

# Disable general log after running queries
$MYSQL "SET GLOBAL general_log = OFF;"

echo "[INFO] Done. General log should have many entries now."