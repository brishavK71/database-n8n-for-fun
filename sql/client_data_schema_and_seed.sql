-- Client data schema and sample post-ETL data for MySQL 8.4.
-- The Compose stack creates client_data; run this script against that database.
-- Run after the ETL workflow has loaded its source data.

USE `client_data`;

CREATE TABLE IF NOT EXISTS `etl_runs` (
  `etl_run_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `pipeline_name` VARCHAR(100) NOT NULL,
  `source_system` VARCHAR(100) NOT NULL,
  `status` ENUM('started', 'completed', 'failed') NOT NULL,
  `records_read` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `records_written` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `started_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `completed_at` DATETIME(6) NULL,
  `error_message` TEXT NULL,
  PRIMARY KEY (`etl_run_id`),
  KEY `idx_etl_runs_pipeline_started` (`pipeline_name`, `started_at`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `customers` (
  `customer_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `source_system` VARCHAR(100) NOT NULL,
  `source_customer_id` VARCHAR(150) NOT NULL,
  `email` VARCHAR(320) NOT NULL,
  `first_name` VARCHAR(100) NOT NULL,
  `last_name` VARCHAR(100) NOT NULL,
  `status` ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
  `country_code` CHAR(2) NOT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `last_etl_run_id` BIGINT UNSIGNED NULL,
  PRIMARY KEY (`customer_id`),
  UNIQUE KEY `uq_customers_source_record` (`source_system`, `source_customer_id`),
  UNIQUE KEY `uq_customers_email` (`email`),
  KEY `idx_customers_status_country` (`status`, `country_code`),
  CONSTRAINT `fk_customers_etl_run`
    FOREIGN KEY (`last_etl_run_id`) REFERENCES `etl_runs` (`etl_run_id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `products` (
  `product_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `source_system` VARCHAR(100) NOT NULL,
  `source_product_id` VARCHAR(150) NOT NULL,
  `sku` VARCHAR(100) NOT NULL,
  `product_name` VARCHAR(255) NOT NULL,
  `category` VARCHAR(100) NOT NULL,
  `unit_price` DECIMAL(12,2) NOT NULL,
  `currency_code` CHAR(3) NOT NULL DEFAULT 'USD',
  `is_active` BOOLEAN NOT NULL DEFAULT TRUE,
  `updated_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  `last_etl_run_id` BIGINT UNSIGNED NULL,
  PRIMARY KEY (`product_id`),
  UNIQUE KEY `uq_products_source_record` (`source_system`, `source_product_id`),
  UNIQUE KEY `uq_products_sku` (`sku`),
  KEY `idx_products_category_active` (`category`, `is_active`),
  CONSTRAINT `fk_products_etl_run`
    FOREIGN KEY (`last_etl_run_id`) REFERENCES `etl_runs` (`etl_run_id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `orders` (
  `order_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `source_system` VARCHAR(100) NOT NULL,
  `source_order_id` VARCHAR(150) NOT NULL,
  `customer_id` BIGINT UNSIGNED NOT NULL,
  `order_status` ENUM('pending', 'paid', 'shipped', 'cancelled', 'refunded') NOT NULL,
  `order_date` DATETIME(6) NOT NULL,
  `total_amount` DECIMAL(12,2) NOT NULL,
  `currency_code` CHAR(3) NOT NULL DEFAULT 'USD',
  `last_etl_run_id` BIGINT UNSIGNED NULL,
  PRIMARY KEY (`order_id`),
  UNIQUE KEY `uq_orders_source_record` (`source_system`, `source_order_id`),
  KEY `idx_orders_customer_date` (`customer_id`, `order_date`),
  KEY `idx_orders_status_date` (`order_status`, `order_date`),
  CONSTRAINT `fk_orders_customer`
    FOREIGN KEY (`customer_id`) REFERENCES `customers` (`customer_id`),
  CONSTRAINT `fk_orders_etl_run`
    FOREIGN KEY (`last_etl_run_id`) REFERENCES `etl_runs` (`etl_run_id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `order_items` (
  `order_item_id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` BIGINT UNSIGNED NOT NULL,
  `product_id` BIGINT UNSIGNED NOT NULL,
  `quantity` DECIMAL(12,3) NOT NULL,
  `unit_price` DECIMAL(12,2) NOT NULL,
  `line_total` DECIMAL(12,2) AS (`quantity` * `unit_price`) STORED,
  PRIMARY KEY (`order_item_id`),
  UNIQUE KEY `uq_order_product` (`order_id`, `product_id`),
  KEY `idx_order_items_product` (`product_id`),
  CONSTRAINT `fk_order_items_order`
    FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`),
  CONSTRAINT `fk_order_items_product`
    FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`)
) ENGINE=InnoDB;

-- Sample ETL completion marker.
INSERT INTO `etl_runs` (
  `pipeline_name`, `source_system`, `status`, `records_read`, `records_written`, `completed_at`
)
VALUES ('sample_customer_orders', 'demo_source', 'completed', 5, 5, CURRENT_TIMESTAMP(6));

SET @sample_etl_run_id = LAST_INSERT_ID();

INSERT INTO `customers` (
  `source_system`, `source_customer_id`, `email`, `first_name`, `last_name`, `status`, `country_code`, `last_etl_run_id`
)
VALUES
  ('demo_source', 'cust-1001', 'ava.chen@example.com', 'Ava', 'Chen', 'active', 'US', @sample_etl_run_id),
  ('demo_source', 'cust-1002', 'liam.smith@example.com', 'Liam', 'Smith', 'active', 'CA', @sample_etl_run_id),
  ('demo_source', 'cust-1003', 'sofia.rossi@example.com', 'Sofia', 'Rossi', 'active', 'IT', @sample_etl_run_id)
ON DUPLICATE KEY UPDATE
  `email` = VALUES(`email`),
  `first_name` = VALUES(`first_name`),
  `last_name` = VALUES(`last_name`),
  `status` = VALUES(`status`),
  `country_code` = VALUES(`country_code`),
  `last_etl_run_id` = VALUES(`last_etl_run_id`);

INSERT INTO `products` (
  `source_system`, `source_product_id`, `sku`, `product_name`, `category`, `unit_price`, `currency_code`, `last_etl_run_id`
)
VALUES
  ('demo_source', 'prod-2001', 'DATA-001', 'Data Connector', 'software', 49.00, 'USD', @sample_etl_run_id),
  ('demo_source', 'prod-2002', 'DATA-002', 'Analytics Bundle', 'software', 129.00, 'USD', @sample_etl_run_id),
  ('demo_source', 'prod-2003', 'DATA-003', 'Priority Support', 'service', 25.00, 'USD', @sample_etl_run_id)
ON DUPLICATE KEY UPDATE
  `sku` = VALUES(`sku`),
  `product_name` = VALUES(`product_name`),
  `category` = VALUES(`category`),
  `unit_price` = VALUES(`unit_price`),
  `currency_code` = VALUES(`currency_code`),
  `last_etl_run_id` = VALUES(`last_etl_run_id`);

INSERT INTO `orders` (
  `source_system`, `source_order_id`, `customer_id`, `order_status`, `order_date`, `total_amount`, `currency_code`, `last_etl_run_id`
)
SELECT 'demo_source', 'order-3001', `customer_id`, 'paid', '2026-09-01 10:30:00', 178.00, 'USD', @sample_etl_run_id
FROM `customers` WHERE `source_system` = 'demo_source' AND `source_customer_id` = 'cust-1001'
ON DUPLICATE KEY UPDATE
  `customer_id` = VALUES(`customer_id`),
  `order_status` = VALUES(`order_status`),
  `order_date` = VALUES(`order_date`),
  `total_amount` = VALUES(`total_amount`),
  `currency_code` = VALUES(`currency_code`),
  `last_etl_run_id` = VALUES(`last_etl_run_id`);

INSERT INTO `orders` (
  `source_system`, `source_order_id`, `customer_id`, `order_status`, `order_date`, `total_amount`, `currency_code`, `last_etl_run_id`
)
SELECT 'demo_source', 'order-3002', `customer_id`, 'shipped', '2026-09-03 14:15:00', 129.00, 'USD', @sample_etl_run_id
FROM `customers` WHERE `source_system` = 'demo_source' AND `source_customer_id` = 'cust-1002'
ON DUPLICATE KEY UPDATE
  `customer_id` = VALUES(`customer_id`),
  `order_status` = VALUES(`order_status`),
  `order_date` = VALUES(`order_date`),
  `total_amount` = VALUES(`total_amount`),
  `currency_code` = VALUES(`currency_code`),
  `last_etl_run_id` = VALUES(`last_etl_run_id`);

INSERT INTO `order_items` (`order_id`, `product_id`, `quantity`, `unit_price`)
SELECT o.`order_id`, p.`product_id`, 1, p.`unit_price`
FROM `orders` o
JOIN `products` p ON p.`source_system` = 'demo_source' AND p.`source_product_id` = 'prod-2001'
WHERE o.`source_system` = 'demo_source' AND o.`source_order_id` = 'order-3001'
ON DUPLICATE KEY UPDATE
  `quantity` = VALUES(`quantity`),
  `unit_price` = VALUES(`unit_price`);

INSERT INTO `order_items` (`order_id`, `product_id`, `quantity`, `unit_price`)
SELECT o.`order_id`, p.`product_id`, 1, p.`unit_price`
FROM `orders` o
JOIN `products` p ON p.`source_system` = 'demo_source' AND p.`source_product_id` = 'prod-2002'
WHERE o.`source_system` = 'demo_source' AND o.`source_order_id` = 'order-3001'
ON DUPLICATE KEY UPDATE
  `quantity` = VALUES(`quantity`),
  `unit_price` = VALUES(`unit_price`);

INSERT INTO `order_items` (`order_id`, `product_id`, `quantity`, `unit_price`)
SELECT o.`order_id`, p.`product_id`, 1, p.`unit_price`
FROM `orders` o
JOIN `products` p ON p.`source_system` = 'demo_source' AND p.`source_product_id` = 'prod-2002'
WHERE o.`source_system` = 'demo_source' AND o.`source_order_id` = 'order-3002'
ON DUPLICATE KEY UPDATE
  `quantity` = VALUES(`quantity`),
  `unit_price` = VALUES(`unit_price`);

-- Quick verification for an n8n MySQL node or a local SQL client.
SELECT
  c.`customer_id`,
  CONCAT(c.`first_name`, ' ', c.`last_name`) AS `customer_name`,
  COUNT(DISTINCT o.`order_id`) AS `order_count`,
  COALESCE(SUM(o.`total_amount`), 0.00) AS `lifetime_value`
FROM `customers` c
LEFT JOIN `orders` o ON o.`customer_id` = c.`customer_id`
GROUP BY c.`customer_id`, c.`first_name`, c.`last_name`
ORDER BY `lifetime_value` DESC;
