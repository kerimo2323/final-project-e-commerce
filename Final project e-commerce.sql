
CREATE DATABASE ecommerce_store
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE ecommerce_store;

-- ============================================================
-- Reference and Lookup Tables
-- ============================================================

-- Countries (for addresses)
CREATE TABLE countries (
  country_id      INT AUTO_INCREMENT PRIMARY KEY,
  iso_code        CHAR(2) NOT NULL UNIQUE,
  name            VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Currencies
CREATE TABLE currencies (
  currency_code   CHAR(3) PRIMARY KEY,
  name            VARCHAR(50) NOT NULL,
  symbol          VARCHAR(10) NOT NULL
) ENGINE=InnoDB;

-- Payment Methods (lookup)
CREATE TABLE payment_methods (
  payment_method_id  TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  method_name        VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Order Statuses (lookup)
CREATE TABLE order_statuses (
  status_code     TINYINT UNSIGNED PRIMARY KEY,
  status_name     VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Shipment Statuses (lookup)
CREATE TABLE shipment_statuses (
  status_code     TINYINT UNSIGNED PRIMARY KEY,
  status_name     VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ============================================================
-- Core Entities
-- ============================================================

-- Users (customers and admins)
CREATE TABLE users (
  user_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email           VARCHAR(255) NOT NULL UNIQUE,
  password_hash   CHAR(60) NOT NULL,
  first_name      VARCHAR(100) NOT NULL,
  last_name       VARCHAR(100) NOT NULL,
  phone           VARCHAR(30),
  is_admin        BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- One-to-One: Each user may have exactly one customer profile (optional)
CREATE TABLE customers (
  customer_id     BIGINT UNSIGNED PRIMARY KEY,
  user_id         BIGINT UNSIGNED NOT NULL UNIQUE,
  birth_date      DATE,
  marketing_opt_in BOOLEAN NOT NULL DEFAULT FALSE,
  CONSTRAINT fk_customers_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Addresses (shipping/billing)
CREATE TABLE addresses (
  address_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT UNSIGNED NOT NULL,
  label           VARCHAR(100) NOT NULL, -- e.g., 'Home', 'Office'
  line1           VARCHAR(255) NOT NULL,
  line2           VARCHAR(255),
  city            VARCHAR(100) NOT NULL,
  state_region    VARCHAR(100),
  postal_code     VARCHAR(30),
  country_id      INT NOT NULL,
  is_default_billing  BOOLEAN NOT NULL DEFAULT FALSE,
  is_default_shipping BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_addresses_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_addresses_country
    FOREIGN KEY (country_id) REFERENCES countries(country_id)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Vendors (suppliers)
CREATE TABLE vendors (
  vendor_id       BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(200) NOT NULL UNIQUE,
  contact_email   VARCHAR(255),
  contact_phone   VARCHAR(50),
  website_url     VARCHAR(255)
) ENGINE=InnoDB;

-- Product Categories (self-referencing tree)
CREATE TABLE categories (
  category_id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  parent_id       BIGINT UNSIGNED,
  name            VARCHAR(150) NOT NULL,
  slug            VARCHAR(160) NOT NULL UNIQUE,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_categories_parent_name UNIQUE (parent_id, name),
  CONSTRAINT fk_categories_parent
    FOREIGN KEY (parent_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- Products
CREATE TABLE products (
  product_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sku             VARCHAR(64) NOT NULL UNIQUE,
  vendor_id       BIGINT UNSIGNED,
  name            VARCHAR(255) NOT NULL,
  description     TEXT,
  price_cents     INT UNSIGNED NOT NULL,        -- store money as integer cents
  currency_code   CHAR(3) NOT NULL,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_products_vendor
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_products_currency
    FOREIGN KEY (currency_code) REFERENCES currencies(currency_code)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Many-to-Many: Product <-> Category
CREATE TABLE product_categories (
  product_id      BIGINT UNSIGNED NOT NULL,
  category_id     BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (product_id, category_id),
  CONSTRAINT fk_product_categories_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_product_categories_category
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Inventory per product per warehouse/location
CREATE TABLE warehouses (
  warehouse_id    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name            VARCHAR(150) NOT NULL UNIQUE,
  country_id      INT NOT NULL,
  city            VARCHAR(100) NOT NULL,
  CONSTRAINT fk_warehouses_country
    FOREIGN KEY (country_id) REFERENCES countries(country_id)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE inventory (
  product_id      BIGINT UNSIGNED NOT NULL,
  warehouse_id    BIGINT UNSIGNED NOT NULL,
  qty_on_hand     INT NOT NULL DEFAULT 0,
  qty_reserved    INT NOT NULL DEFAULT 0,
  PRIMARY KEY (product_id, warehouse_id),
  CONSTRAINT fk_inventory_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_inventory_warehouse
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(warehouse_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT ck_inventory_nonneg CHECK (qty_on_hand >= 0 AND qty_reserved >= 0)
) ENGINE=InnoDB;

-- ============================================================
-- Orders and Payments
-- ============================================================

-- Carts (optional pre-order container)
CREATE TABLE carts (
  cart_id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT UNSIGNED NOT NULL UNIQUE,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_carts_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cart_items (
  cart_id         BIGINT UNSIGNED NOT NULL,
  product_id      BIGINT UNSIGNED NOT NULL,
  quantity        INT NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (cart_id, product_id),
  CONSTRAINT fk_cart_items_cart
    FOREIGN KEY (cart_id) REFERENCES carts(cart_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_cart_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Orders
CREATE TABLE orders (
  order_id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id         BIGINT UNSIGNED NOT NULL,
  billing_address_id  BIGINT UNSIGNED NOT NULL,
  shipping_address_id BIGINT UNSIGNED NOT NULL,
  currency_code   CHAR(3) NOT NULL,
  payment_method_id TINYINT UNSIGNED NOT NULL,
  status_code     TINYINT UNSIGNED NOT NULL,
  subtotal_cents  INT UNSIGNED NOT NULL,
  shipping_cents  INT UNSIGNED NOT NULL DEFAULT 0,
  tax_cents       INT UNSIGNED NOT NULL DEFAULT 0,
  discount_cents  INT UNSIGNED NOT NULL DEFAULT 0,
  grand_total_cents INT UNSIGNED NOT NULL,
  placed_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_orders_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE,
  CONSTRAINT fk_orders_billing_address
    FOREIGN KEY (billing_address_id) REFERENCES addresses(address_id)
    ON UPDATE CASCADE,
  CONSTRAINT fk_orders_shipping_address
    FOREIGN KEY (shipping_address_id) REFERENCES addresses(address_id)
    ON UPDATE CASCADE,
  CONSTRAINT fk_orders_currency
    FOREIGN KEY (currency_code) REFERENCES currencies(currency_code)
    ON UPDATE CASCADE,
  CONSTRAINT fk_orders_payment_method
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(payment_method_id)
    ON UPDATE CASCADE,
  CONSTRAINT fk_orders_status
    FOREIGN KEY (status_code) REFERENCES order_statuses(status_code)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Order Items (snapshot of product price at purchase time)
CREATE TABLE order_items (
  order_item_id   BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id        BIGINT UNSIGNED NOT NULL,
  product_id      BIGINT UNSIGNED NOT NULL,
  sku             VARCHAR(64) NOT NULL,
  product_name    VARCHAR(255) NOT NULL,
  unit_price_cents INT UNSIGNED NOT NULL,
  quantity        INT NOT NULL CHECK (quantity > 0),
  line_total_cents INT UNSIGNED NOT NULL,
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_order_items_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Payments (One-to-One or One-to-Many with orders; allow split payments)
CREATE TABLE payments (
  payment_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id        BIGINT UNSIGNED NOT NULL,
  payment_method_id TINYINT UNSIGNED NOT NULL,
  amount_cents    INT UNSIGNED NOT NULL,
  currency_code   CHAR(3) NOT NULL,
  authorization_code VARCHAR(100),
  successful      BOOLEAN NOT NULL DEFAULT FALSE,
  processed_at    TIMESTAMP NULL,
  CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_payments_method
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(payment_method_id)
    ON UPDATE CASCADE,
  CONSTRAINT fk_payments_currency
    FOREIGN KEY (currency_code) REFERENCES currencies(currency_code)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Shipments
CREATE TABLE shipments (
  shipment_id     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  order_id        BIGINT UNSIGNED NOT NULL,
  tracking_number VARCHAR(100),
  carrier         VARCHAR(100),
  status_code     TINYINT UNSIGNED NOT NULL,
  shipped_at      TIMESTAMP NULL,
  delivered_at    TIMESTAMP NULL,
  CONSTRAINT fk_shipments_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_shipments_status
    FOREIGN KEY (status_code) REFERENCES shipment_statuses(status_code)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE shipment_items (
  shipment_id     BIGINT UNSIGNED NOT NULL,
  order_item_id   BIGINT UNSIGNED NOT NULL,
  quantity        INT NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (shipment_id, order_item_id),
  CONSTRAINT fk_shipment_items_shipment
    FOREIGN KEY (shipment_id) REFERENCES shipments(shipment_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_shipment_items_order_item
    FOREIGN KEY (order_item_id) REFERENCES order_items(order_item_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- Reviews, Promotions, and Auditing
-- ============================================================

-- Product Reviews (one user can review a product once)
CREATE TABLE product_reviews (
  review_id       BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id      BIGINT UNSIGNED NOT NULL,
  user_id         BIGINT UNSIGNED NOT NULL,
  rating          TINYINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title           VARCHAR(200),
  body            TEXT,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_reviews_user_product UNIQUE (product_id, user_id),
  CONSTRAINT fk_reviews_product
    FOREIGN KEY (product_id) REFERENCES products(product_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_reviews_user
    FOREIGN KEY (user_id) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- Coupons / Promotions
CREATE TABLE coupons (
  coupon_id       BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code            VARCHAR(50) NOT NULL UNIQUE,
  description     VARCHAR(255),
  discount_type   ENUM('PERCENT','FIXED') NOT NULL,
  discount_value_cents INT UNSIGNED NOT NULL, -- for FIXED
  percent_off     DECIMAL(5,2),               -- for PERCENT, e.g., 15.00
  max_uses        INT UNSIGNED,
  per_user_limit  INT UNSIGNED,
  valid_from      DATETIME NOT NULL,
  valid_to        DATETIME NOT NULL,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT ck_coupons_value CHECK (
    (discount_type = 'FIXED' AND discount_value_cents > 0) OR
    (discount_type = 'PERCENT' AND percent_off > 0)
  )
) ENGINE=InnoDB;

-- Many-to-Many: Coupons applied to Orders
CREATE TABLE order_coupons (
  order_id        BIGINT UNSIGNED NOT NULL,
  coupon_id       BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (order_id, coupon_id),
  CONSTRAINT fk_order_coupons_order
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_order_coupons_coupon
    FOREIGN KEY (coupon_id) REFERENCES coupons(coupon_id)
    ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Audit table (example)
CREATE TABLE audit_logs (
  audit_id        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  entity_type     VARCHAR(50) NOT NULL,
  entity_id       BIGINT UNSIGNED NOT NULL,
  action          ENUM('CREATE','UPDATE','DELETE') NOT NULL,
  changed_by      BIGINT UNSIGNED,
  changed_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  details         JSON,
  CONSTRAINT fk_audit_user
    FOREIGN KEY (changed_by) REFERENCES users(user_id)
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
-- Indexing for performance
-- ============================================================

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_addresses_user ON addresses(user_id);
CREATE INDEX idx_products_vendor ON products(vendor_id);
CREATE INDEX idx_products_active ON products(is_active);
CREATE INDEX idx_product_categories_category ON product_categories(category_id);
CREATE INDEX idx_inventory_warehouse ON inventory(warehouse_id);
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status_code);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_shipments_order ON shipments(order_id);
CREATE INDEX idx_reviews_product ON product_reviews(product_id);

-- ============================================================
-- Seed minimal lookup data (optional)
-- ============================================================

INSERT INTO countries (iso_code, name) VALUES
  ('US', 'United States'),
  ('CA', 'Canada'),
  ('GB', 'United Kingdom');

INSERT INTO currencies (currency_code, name, symbol) VALUES
  ('USD', 'US Dollar', '$'),
  ('CAD', 'Canadian Dollar', '$'),
  ('GBP', 'British Pound', '£');

INSERT INTO payment_methods (method_name) VALUES
  ('Credit Card'),
  ('PayPal'),
  ('Bank Transfer');

INSERT INTO order_statuses (status_code, status_name) VALUES
  (1, 'Pending'),
  (2, 'Paid'),
  (3, 'Processing'),
  (4, 'Shipped'),
  (5, 'Delivered'),
  (6, 'Cancelled'),
  (7, 'Refunded');

INSERT INTO shipment_statuses (status_code, status_name) VALUES
  (1, 'Label Created'),
  (2, 'In Transit'),
  (3, 'Out for Delivery'),
  (4, 'Delivered'),
  (5, 'Exception');

-- ============================================================
-- Example constraints demonstrating relationships
-- - One-to-One: users -> customers (unique user_id)
-- - One-to-Many: users -> addresses, orders; vendors -> products; orders -> order_items
-- - Many-to-Many: products <-> categories; orders <-> coupons
-- ============================================================
