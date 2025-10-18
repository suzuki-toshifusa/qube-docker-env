-- データベース: test（composeで自動作成済み）
USE test;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50),
  age INT,
  city VARCHAR(50),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  amount DECIMAL(10,2),
  status ENUM('pending','paid','shipped','cancelled'),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- ダミーデータ投入
INSERT INTO users (name, age, city) VALUES
('Alice', 25, 'Tokyo'),
('Bob', 32, 'Osaka'),
('Charlie', 28, 'Nagoya'),
('Diana', 41, 'Fukuoka'),
('Eve', 37, 'Sapporo');

INSERT INTO orders (user_id, amount, status) VALUES
(1, 1000.00, 'paid'),
(2, 250.00, 'pending'),
(3, 75.50, 'shipped'),
(4, 400.00, 'cancelled'),
(5, 1200.00, 'paid');

SET FOREIGN_KEY_CHECKS = 1;