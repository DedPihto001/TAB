-- SQLite / DBeaver. Запустите весь файл один раз на пустой базе данных.
-- products хранит товары; каждая строка orders — одна позиция заказа.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    price REAL NOT NULL CHECK (price >= 0),
    list_price REAL NOT NULL CHECK (list_price >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0)
);

CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY,
    order_number TEXT NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    ordered_at TEXT NOT NULL,
    status TEXT NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(id),
    UNIQUE (order_number, product_id)
);

-- Три ручные вставки товаров.
INSERT INTO products (sku, name, category, price, list_price, stock)
VALUES ('MAN-001', 'Coffee Beans', 'Beverages', 12.50, 12.50, 40)
ON CONFLICT (sku) DO NOTHING;

INSERT INTO products (sku, name, category, price, list_price, stock)
VALUES ('MAN-002', 'Whole Milk', 'Dairy', 2.20, 2.20, 60)
ON CONFLICT (sku) DO NOTHING;

INSERT INTO products (sku, name, category, price, list_price, stock)
VALUES ('MAN-003', 'Olive Oil', 'Pantry', 8.75, 8.75, 12)
ON CONFLICT (sku) DO NOTHING;

-- Массовая вставка 120 товаров через рекурсивный CTE.
WITH RECURSIVE sequence(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM sequence WHERE n < 120
)
INSERT INTO products (sku, name, category, price, list_price, stock)
SELECT
    printf('SKU-%04d', n),
    printf('Product %03d', n),
    CASE (n - 1) % 6
        WHEN 0 THEN 'Produce'
        WHEN 1 THEN 'Bakery'
        WHEN 2 THEN 'Dairy'
        WHEN 3 THEN 'Beverages'
        WHEN 4 THEN 'Pantry'
        ELSE 'Household'
    END,
    ROUND(1.25 + n * 0.37, 2),
    ROUND(1.25 + n * 0.37, 2),
    (n * 7) % 50 + 1
FROM sequence
WHERE 1
ON CONFLICT (sku) DO NOTHING;

-- Временная тестовая строка нужна только для демонстрации безопасного DELETE.
INSERT INTO products (sku, name, category, price, list_price, stock)
VALUES ('TEST-DELETE', 'Temporary Test Product', 'Test', 1.00, 1.00, 1)
ON CONFLICT (sku) DO NOTHING;

-- Безопасное удаление: условие точно ограничивает тестовый SKU.
DELETE FROM products
WHERE sku = 'TEST-DELETE';

-- Заказы для JOIN и расчёта выручки по категориям.
-- Перед повторным запуском удаляем только демонстрационные заказы.
DELETE FROM orders
WHERE order_number IN ('ORD-1001', 'ORD-1002', 'ORD-1003', 'ORD-1004');

INSERT INTO orders (order_number, product_id, quantity, ordered_at, status)
SELECT 'ORD-1001', id, 2, '2026-10-01', 'shipped' FROM products WHERE sku = 'MAN-001'
ON CONFLICT (order_number, product_id) DO NOTHING;
INSERT INTO orders (order_number, product_id, quantity, ordered_at, status)
SELECT 'ORD-1001', id, 3, '2026-10-01', 'shipped' FROM products WHERE sku = 'MAN-002'
ON CONFLICT (order_number, product_id) DO NOTHING;
INSERT INTO orders (order_number, product_id, quantity, ordered_at, status)
SELECT 'ORD-1002', id, 1, '2026-10-02', 'processing' FROM products WHERE sku = 'MAN-003'
ON CONFLICT (order_number, product_id) DO NOTHING;
INSERT INTO orders (order_number, product_id, quantity, ordered_at, status)
SELECT 'ORD-1002', id, 3, '2026-10-02', 'processing' FROM products WHERE sku = 'MAN-002'
ON CONFLICT (order_number, product_id) DO NOTHING;
INSERT INTO orders (order_number, product_id, quantity, ordered_at, status)
SELECT 'ORD-1003', id, 2, '2026-10-03', 'delivered' FROM products WHERE sku = 'SKU-0004'
ON CONFLICT (order_number, product_id) DO NOTHING;
INSERT INTO orders (order_number, product_id, quantity, ordered_at, status)
SELECT 'ORD-1003', id, 1, '2026-10-03', 'delivered' FROM products WHERE sku = 'SKU-0007'
ON CONFLICT (order_number, product_id) DO NOTHING;
INSERT INTO orders (order_number, product_id, quantity, ordered_at, status)
SELECT 'ORD-1004', id, 5, '2026-10-04', 'shipped' FROM products WHERE sku = 'SKU-0010'
ON CONFLICT (order_number, product_id) DO NOTHING;
INSERT INTO orders (order_number, product_id, quantity, ordered_at, status)
SELECT 'ORD-1004', id, 2, '2026-10-04', 'shipped' FROM products WHERE sku = 'SKU-0013'
ON CONFLICT (order_number, product_id) DO NOTHING;

-- UPDATE 1: скидка 10% на товары массовой вставки из категории Beverages.
-- list_price сохраняет исходную цену; условие делает запрос повторяемым.
UPDATE products
SET price = ROUND(list_price * 0.90, 2)
WHERE category = 'Beverages'
  AND sku LIKE 'SKU-%'
  AND price <> ROUND(list_price * 0.90, 2);

-- UPDATE 2: точечная цена по SKU.
UPDATE products
SET price = 9.99
WHERE sku = 'SKU-0001'
  AND price <> 9.99;

-- UPDATE 3: корректировка остатка конкретного товара по SKU.
UPDATE products
SET stock = 17
WHERE sku = 'MAN-003'
  AND stock <> 17;

-- Топ-10 товаров по цене.
SELECT sku, name, category, price
FROM products
WHERE price > 0
ORDER BY price DESC, sku
LIMIT 10;

-- Средняя цена и число товаров в категориях, где товаров больше пяти.
SELECT category, COUNT(*) AS product_count, AVG(price) AS average_price
FROM products
GROUP BY category
HAVING COUNT(*) > 5
ORDER BY product_count DESC, category;

-- Поиск без учёта регистра: UPPER(column) LIKE 'ABC%'.
SELECT sku, name, category, price
FROM products
WHERE UPPER(name) LIKE 'COFFEE%'
ORDER BY name;

-- Детализация заказов: название товара и сумма позиции.
SELECT
    o.order_number,
    o.ordered_at,
    o.status,
    p.name AS product_name,
    p.category,
    o.quantity,
    p.price,
    ROUND(o.quantity * p.price, 2) AS line_total
FROM orders AS o
JOIN products AS p ON p.id = o.product_id
ORDER BY o.order_number, p.name;

-- Сумма заказов по категориям.
SELECT
    p.category,
    COUNT(*) AS order_lines,
    SUM(o.quantity) AS units_ordered,
    ROUND(SUM(o.quantity * p.price), 2) AS category_total
FROM orders AS o
JOIN products AS p ON p.id = o.product_id
GROUP BY p.category
ORDER BY category_total DESC;

-- Безопасный шаблон с фиксированным значением; параметризованный вариант
-- для Python sqlite3 показан в функции find_products_safe файла seed.py.
SELECT sku, name, category
FROM products
WHERE UPPER(name) LIKE 'COFFEE%'
ORDER BY name;
