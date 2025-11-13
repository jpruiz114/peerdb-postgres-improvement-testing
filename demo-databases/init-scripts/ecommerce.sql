-- E-commerce Demo Database
-- This simulates a typical e-commerce application database

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true
);

-- Products table
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    stock_quantity INTEGER DEFAULT 0,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Orders table
CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    shipping_address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Order items table
CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample users
INSERT INTO users (email, first_name, last_name, created_at) VALUES
    ('alice@example.com', 'Alice', 'Smith', NOW() - INTERVAL '30 days'),
    ('bob@example.com', 'Bob', 'Johnson', NOW() - INTERVAL '25 days'),
    ('charlie@example.com', 'Charlie', 'Williams', NOW() - INTERVAL '20 days'),
    ('diana@example.com', 'Diana', 'Brown', NOW() - INTERVAL '15 days'),
    ('eve@example.com', 'Eve', 'Jones', NOW() - INTERVAL '10 days');

-- Insert sample products
INSERT INTO products (name, description, price, stock_quantity, category) VALUES
    ('Laptop Pro 15', 'High-performance laptop with 16GB RAM', 1299.99, 50, 'Electronics'),
    ('Wireless Mouse', 'Ergonomic wireless mouse', 29.99, 200, 'Accessories'),
    ('Mechanical Keyboard', 'RGB mechanical keyboard', 149.99, 75, 'Accessories'),
    ('USB-C Hub', '7-in-1 USB-C hub with HDMI', 79.99, 100, 'Accessories'),
    ('Monitor 27"', '4K 27-inch monitor', 399.99, 30, 'Electronics'),
    ('Webcam HD', '1080p HD webcam', 89.99, 150, 'Accessories'),
    ('Standing Desk', 'Adjustable height standing desk', 599.99, 20, 'Furniture'),
    ('Desk Chair', 'Ergonomic office chair', 299.99, 40, 'Furniture');

-- Insert sample orders
INSERT INTO orders (user_id, total_amount, status, shipping_address, created_at) VALUES
    (1, 1429.98, 'completed', '123 Main St, City, State 12345', NOW() - INTERVAL '5 days'),
    (2, 179.98, 'shipped', '456 Oak Ave, City, State 12345', NOW() - INTERVAL '3 days'),
    (3, 599.99, 'pending', '789 Pine Rd, City, State 12345', NOW() - INTERVAL '1 day'),
    (1, 89.99, 'completed', '123 Main St, City, State 12345', NOW() - INTERVAL '10 days'),
    (4, 899.98, 'processing', '321 Elm St, City, State 12345', NOW() - INTERVAL '2 days');

-- Insert sample order items
INSERT INTO order_items (order_id, product_id, quantity, price) VALUES
    (1, 1, 1, 1299.99),  -- Laptop
    (1, 2, 1, 29.99),    -- Mouse
    (1, 3, 1, 149.99),   -- Keyboard
    (2, 4, 1, 79.99),    -- USB-C Hub
    (2, 5, 1, 99.99),    -- Monitor (discounted)
    (3, 7, 1, 599.99),   -- Standing Desk
    (4, 6, 1, 89.99),    -- Webcam
    (5, 1, 1, 1299.99),  -- Laptop
    (5, 8, 1, 299.99);   -- Desk Chair

-- Create indexes for better query performance
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_created_at ON orders(created_at);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);
CREATE INDEX idx_products_category ON products(category);

-- Create a view for order summaries
CREATE OR REPLACE VIEW order_summary AS
SELECT 
    o.id as order_id,
    u.email as customer_email,
    u.first_name || ' ' || u.last_name as customer_name,
    o.total_amount,
    o.status,
    o.created_at,
    COUNT(oi.id) as item_count
FROM orders o
JOIN users u ON o.user_id = u.id
LEFT JOIN order_items oi ON o.id = oi.order_id
GROUP BY o.id, u.email, u.first_name, u.last_name, o.total_amount, o.status, o.created_at;

-- ============================================
-- TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at on users table
CREATE TRIGGER trigger_update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to auto-update updated_at on products table
CREATE TRIGGER trigger_update_products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger to auto-update updated_at on orders table
CREATE TRIGGER trigger_update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to update stock quantity when order items are inserted
CREATE OR REPLACE FUNCTION update_product_stock_on_order()
RETURNS TRIGGER AS $$
BEGIN
    -- Decrease stock when order item is added
    UPDATE products
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE id = NEW.product_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update stock when order items are created
CREATE TRIGGER trigger_update_stock_on_order_item
    AFTER INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION update_product_stock_on_order();

-- Function to recalculate order total when order items change
CREATE OR REPLACE FUNCTION recalculate_order_total()
RETURNS TRIGGER AS $$
DECLARE
    new_total DECIMAL(10, 2);
BEGIN
    -- Calculate new total from all order items
    SELECT COALESCE(SUM(quantity * price), 0)
    INTO new_total
    FROM order_items
    WHERE order_id = COALESCE(NEW.order_id, OLD.order_id);
    
    -- Update the order total
    UPDATE orders
    SET total_amount = new_total
    WHERE id = COALESCE(NEW.order_id, OLD.order_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger to recalculate order total when order items are inserted
CREATE TRIGGER trigger_recalculate_total_on_insert
    AFTER INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION recalculate_order_total();

-- Trigger to recalculate order total when order items are updated
CREATE TRIGGER trigger_recalculate_total_on_update
    AFTER UPDATE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION recalculate_order_total();

-- Trigger to recalculate order total when order items are deleted
CREATE TRIGGER trigger_recalculate_total_on_delete
    AFTER DELETE ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION recalculate_order_total();

-- Function to log order status changes for audit
CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        -- In a real system, you'd insert into an audit table
        -- For demo purposes, we'll just raise a notice
        RAISE NOTICE 'Order % status changed from % to %', NEW.id, OLD.status, NEW.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to log order status changes
CREATE TRIGGER trigger_log_order_status_change
    AFTER UPDATE OF status ON orders
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION log_order_status_change();

-- Function to validate order item quantity
CREATE OR REPLACE FUNCTION validate_order_item_quantity()
RETURNS TRIGGER AS $$
DECLARE
    available_stock INTEGER;
BEGIN
    -- Check if enough stock is available
    SELECT stock_quantity INTO available_stock
    FROM products
    WHERE id = NEW.product_id;
    
    IF available_stock < NEW.quantity THEN
        RAISE EXCEPTION 'Insufficient stock. Available: %, Requested: %', available_stock, NEW.quantity;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to validate order item quantity before insert
CREATE TRIGGER trigger_validate_order_item_quantity
    BEFORE INSERT ON order_items
    FOR EACH ROW
    EXECUTE FUNCTION validate_order_item_quantity();

-- Function to update user last activity timestamp
CREATE OR REPLACE FUNCTION update_user_last_activity()
RETURNS TRIGGER AS $$
BEGIN
    -- Update user's updated_at when they place an order
    UPDATE users
    SET updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.user_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update user activity when order is created
CREATE TRIGGER trigger_update_user_activity_on_order
    AFTER INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_user_last_activity();

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO postgres;

