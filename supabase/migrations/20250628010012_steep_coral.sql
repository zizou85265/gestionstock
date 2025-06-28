/*
  # Complete Database Schema for Clothing Store Management System

  1. New Tables
    - `users` - System users (admins and sales agents)
    - `customers` - Customer database with contact information
    - `products` - Clothing catalog with pricing and inventory
    - `transactions` - Sales and rental transaction history
    - `rentals` - Specific rental management with dates
    - `rental_calendar` - Reservation calendar to prevent conflicts
    - `payments` - Payment and installment tracking

  2. Security
    - Enable RLS on all tables
    - Role-based policies for data access
    - Performance indexes for optimal queries

  3. Sample Data
    - Demo users, customers, and products
*/

-- Drop existing triggers and policies to avoid conflicts
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
DROP TRIGGER IF EXISTS update_customers_updated_at ON customers;
DROP TRIGGER IF EXISTS update_products_updated_at ON products;

-- Drop existing policies
DO $$ 
BEGIN
    -- Drop all existing policies for users table
    DROP POLICY IF EXISTS "Users can read all data" ON users;
    DROP POLICY IF EXISTS "Admins can manage users" ON users;
    DROP POLICY IF EXISTS "Allow insert to admins" ON users;
    DROP POLICY IF EXISTS "Allow update to admins" ON users;
    DROP POLICY IF EXISTS "Allow login by email/password" ON users;
    DROP POLICY IF EXISTS "Allow logged-in users to read active users" ON users;
    DROP POLICY IF EXISTS "Allow read to authenticated users" ON users;
    
    -- Drop policies for other tables
    DROP POLICY IF EXISTS "Users can read customers" ON customers;
    DROP POLICY IF EXISTS "Users can manage customers" ON customers;
    DROP POLICY IF EXISTS "Users can read products" ON products;
    DROP POLICY IF EXISTS "Users can manage products" ON products;
    DROP POLICY IF EXISTS "Users can read transactions" ON transactions;
    DROP POLICY IF EXISTS "Users can create transactions" ON transactions;
    DROP POLICY IF EXISTS "Users can update transactions" ON transactions;
    DROP POLICY IF EXISTS "Users can read rentals" ON rentals;
    DROP POLICY IF EXISTS "Users can manage rentals" ON rentals;
    DROP POLICY IF EXISTS "Users can read rental calendar" ON rental_calendar;
    DROP POLICY IF EXISTS "Users can manage rental calendar" ON rental_calendar;
    DROP POLICY IF EXISTS "Users can read payments" ON payments;
    DROP POLICY IF EXISTS "Users can manage payments" ON payments;
EXCEPTION
    WHEN undefined_object THEN
        NULL; -- Ignore if policies don't exist
END $$;

-- Extension pour les UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table des utilisateurs du système
CREATE TABLE IF NOT EXISTS users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  email text UNIQUE NOT NULL,
  password text NOT NULL DEFAULT '123456',
  role text NOT NULL CHECK (role IN ('admin', 'agent')),
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table des clients
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text UNIQUE NOT NULL,
  email text,
  address text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table des produits
CREATE TABLE IF NOT EXISTS products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL,
  size text NOT NULL,
  color text NOT NULL,
  brand text NOT NULL,
  purchase_price decimal(10,2) NOT NULL DEFAULT 0,
  sale_price decimal(10,2) NOT NULL DEFAULT 0,
  rental_price_per_day decimal(10,2) NOT NULL DEFAULT 0,
  stock integer NOT NULL DEFAULT 0,
  description text DEFAULT '',
  barcode text,
  is_available_for_rental boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Table des transactions (ventes et locations)
CREATE TABLE IF NOT EXISTS transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL CHECK (type IN ('sale', 'rental')),
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  product_name text NOT NULL,
  quantity integer NOT NULL DEFAULT 1,
  unit_price decimal(10,2) NOT NULL,
  total_amount decimal(10,2) NOT NULL,
  discount decimal(5,2) DEFAULT 0,
  discount_amount decimal(10,2) DEFAULT 0,
  paid_amount decimal(10,2) DEFAULT 0,
  remaining_amount decimal(10,2) DEFAULT 0,
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  customer_email text,
  status text NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'pending', 'returned', 'cancelled', 'partial')),
  agent_id uuid REFERENCES users(id),
  agent_name text NOT NULL,
  notes text,
  created_at timestamptz DEFAULT now()
);

-- Table spécifique pour les locations
CREATE TABLE IF NOT EXISTS rentals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid REFERENCES transactions(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  customer_email text,
  rental_start_date date NOT NULL,
  rental_end_date date NOT NULL,
  rental_days integer NOT NULL,
  daily_rate decimal(10,2) NOT NULL,
  total_amount decimal(10,2) NOT NULL,
  discount decimal(5,2) DEFAULT 0,
  discount_amount decimal(10,2) DEFAULT 0,
  paid_amount decimal(10,2) DEFAULT 0,
  remaining_amount decimal(10,2) DEFAULT 0,
  deposit_amount decimal(10,2) DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'returned', 'overdue', 'cancelled', 'partial')),
  agent_id uuid REFERENCES users(id),
  agent_name text NOT NULL,
  notes text,
  created_at timestamptz DEFAULT now(),
  returned_at timestamptz
);

-- Table calendrier des réservations
CREATE TABLE IF NOT EXISTS rental_calendar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES products(id) ON DELETE CASCADE,
  rental_id uuid REFERENCES rentals(id) ON DELETE CASCADE,
  reserved_date date NOT NULL,
  status text NOT NULL DEFAULT 'reserved' CHECK (status IN ('reserved', 'occupied', 'available')),
  created_at timestamptz DEFAULT now(),
  UNIQUE(product_id, reserved_date)
);

-- Table des paiements et versements
CREATE TABLE IF NOT EXISTS payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id uuid REFERENCES transactions(id) ON DELETE CASCADE,
  rental_id uuid REFERENCES rentals(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES customers(id),
  amount decimal(10,2) NOT NULL,
  payment_method text DEFAULT 'cash' CHECK (payment_method IN ('cash', 'card', 'transfer')),
  payment_date timestamptz DEFAULT now(),
  notes text,
  agent_id uuid REFERENCES users(id),
  agent_name text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Fonction pour mettre à jour updated_at automatiquement
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers pour updated_at (avec vérification d'existence)
DO $$
BEGIN
    -- Trigger for users table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'update_users_updated_at' 
        AND event_object_table = 'users'
    ) THEN
        CREATE TRIGGER update_users_updated_at 
            BEFORE UPDATE ON users
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;

    -- Trigger for customers table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'update_customers_updated_at' 
        AND event_object_table = 'customers'
    ) THEN
        CREATE TRIGGER update_customers_updated_at 
            BEFORE UPDATE ON customers
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;

    -- Trigger for products table
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.triggers 
        WHERE trigger_name = 'update_products_updated_at' 
        AND event_object_table = 'products'
    ) THEN
        CREATE TRIGGER update_products_updated_at 
            BEFORE UPDATE ON products
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rentals ENABLE ROW LEVEL SECURITY;
ALTER TABLE rental_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Politiques RLS pour users
CREATE POLICY "Users can read all data" ON users 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins can manage users" ON users 
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Allow insert to admins" ON users 
  FOR INSERT TO authenticated WITH CHECK (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Allow update to admins" ON users 
  FOR UPDATE TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Allow login by email/password" ON users 
  FOR SELECT TO anon USING (is_active = true);

CREATE POLICY "Allow logged-in users to read active users" ON users 
  FOR SELECT TO public USING (is_active = true);

-- Politiques RLS pour customers
CREATE POLICY "Users can read customers" ON customers 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage customers" ON customers 
  FOR ALL TO authenticated USING (true);

-- Politiques RLS pour products
CREATE POLICY "Users can read products" ON products 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage products" ON products 
  FOR ALL TO authenticated USING (true);

-- Politiques RLS pour transactions
CREATE POLICY "Users can read transactions" ON transactions 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can create transactions" ON transactions 
  FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Users can update transactions" ON transactions 
  FOR UPDATE TO authenticated USING (true);

-- Politiques RLS pour rentals
CREATE POLICY "Users can read rentals" ON rentals 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage rentals" ON rentals 
  FOR ALL TO authenticated USING (true);

-- Politiques RLS pour rental_calendar
CREATE POLICY "Users can read rental calendar" ON rental_calendar 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage rental calendar" ON rental_calendar 
  FOR ALL TO authenticated USING (true);

-- Politiques RLS pour payments
CREATE POLICY "Users can read payments" ON payments 
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can manage payments" ON payments 
  FOR ALL TO authenticated USING (true);

-- Index pour améliorer les performances (avec vérification d'existence)
DO $$
BEGIN
    -- Index for products
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_products_category') THEN
        CREATE INDEX idx_products_category ON products(category);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_products_brand') THEN
        CREATE INDEX idx_products_brand ON products(brand);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_products_barcode') THEN
        CREATE INDEX idx_products_barcode ON products(barcode);
    END IF;
    
    -- Index for transactions
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_transactions_customer_phone') THEN
        CREATE INDEX idx_transactions_customer_phone ON transactions(customer_phone);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_transactions_created_at') THEN
        CREATE INDEX idx_transactions_created_at ON transactions(created_at);
    END IF;
    
    -- Index for rentals
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_rentals_dates') THEN
        CREATE INDEX idx_rentals_dates ON rentals(rental_start_date, rental_end_date);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_rentals_status') THEN
        CREATE INDEX idx_rentals_status ON rentals(status);
    END IF;
    
    -- Index for rental_calendar
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_rental_calendar_date') THEN
        CREATE INDEX idx_rental_calendar_date ON rental_calendar(reserved_date);
    END IF;
    
    -- Index for payments
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_payments_date') THEN
        CREATE INDEX idx_payments_date ON payments(payment_date);
    END IF;
END $$;

-- Données de démonstration
INSERT INTO users (name, email, password, role) VALUES
  ('Administrateur Principal', 'admin@boutique.com', 'hamaza44', 'admin'),
  ('Agent de Vente', 'agent@boutique.com', '123456', 'agent'),
  ('Hamza Admin', 'hamza@halistock.com', 'hamaza44', 'admin'),
  ('Sarah Agent', 'sarah@halistock.com', '123456', 'agent')
ON CONFLICT (email) DO NOTHING;

INSERT INTO customers (name, phone, email, address) VALUES
  ('Ahmed Benali', '0555123456', 'ahmed.benali@email.com', 'Alger Centre, Rue Didouche Mourad'),
  ('Fatima Khelifi', '0666789012', 'fatima.khelifi@email.com', 'Oran, Hai El Makkari'),
  ('Mohamed Saidi', '0777345678', 'mohamed.saidi@email.com', 'Constantine, Rue Larbi Ben Mhidi'),
  ('Amina Boudiaf', '0555987654', 'amina.boudiaf@email.com', 'Annaba, Centre Ville'),
  ('Karim Meziane', '0666543210', 'karim.meziane@email.com', 'Tlemcen, Rue de la République')
ON CONFLICT (phone) DO NOTHING;

INSERT INTO products (name, category, size, color, brand, purchase_price, sale_price, rental_price_per_day, stock, description, barcode, is_available_for_rental) VALUES
  ('Robe de Soirée Élégante', 'Robes', 'M', 'Noir', 'Chanel', 180.00, 350.00, 30.00, 3, 'Robe élégante parfaite pour les occasions spéciales, tissu haute qualité', 'CHN001', true),
  ('Costume Homme Classique', 'Costumes', 'L', 'Bleu Marine', 'Hugo Boss', 250.00, 480.00, 40.00, 2, 'Costume classique pour homme, coupe moderne', 'HB002', true),
  ('Veste en Cuir Premium', 'Vestes', 'S', 'Marron', 'Zara', 120.00, 220.00, 18.00, 4, 'Veste en cuir véritable, style décontracté', 'ZR003', true),
  ('Robe de Mariée', 'Robes', 'M', 'Blanc', 'Vera Wang', 500.00, 1200.00, 80.00, 1, 'Robe de mariée luxueuse avec dentelle française', 'VW004', true),
  ('Smoking de Luxe', 'Costumes', 'L', 'Noir', 'Armani', 300.00, 650.00, 50.00, 2, 'Smoking élégant pour événements formels', 'AR005', true),
  ('Blazer Femme', 'Vestes', 'M', 'Gris', 'Max Mara', 150.00, 280.00, 22.00, 3, 'Blazer professionnel pour femme', 'MM006', true),
  ('Robe Cocktail', 'Robes', 'S', 'Rouge', 'Dior', 200.00, 420.00, 35.00, 2, 'Robe cocktail sophistiquée', 'DR007', true),
  ('Pantalon Costume', 'Pantalons', 'L', 'Noir', 'Hugo Boss', 80.00, 150.00, 12.00, 5, 'Pantalon de costume assorti', 'HB008', false),
  ('Chemise Blanche', 'Chemises', 'M', 'Blanc', 'Ralph Lauren', 60.00, 120.00, 8.00, 8, 'Chemise blanche classique', 'RL009', false),
  ('Cravate Soie', 'Accessoires', 'Unique', 'Bleu', 'Hermès', 40.00, 80.00, 5.00, 10, 'Cravate en soie pure', 'HM010', false)
ON CONFLICT DO NOTHING;

-- Quelques transactions de démonstration
DO $$
DECLARE
    product_uuid uuid;
    user_uuid uuid;
BEGIN
    -- Get product and user IDs for demo transaction
    SELECT id INTO product_uuid FROM products WHERE name = 'Chemise Blanche' LIMIT 1;
    SELECT id INTO user_uuid FROM users WHERE email = 'agent@boutique.com' LIMIT 1;
    
    -- Insert demo transaction if both IDs exist
    IF product_uuid IS NOT NULL AND user_uuid IS NOT NULL THEN
        INSERT INTO transactions (type, product_id, product_name, quantity, unit_price, total_amount, paid_amount, customer_name, customer_phone, customer_email, status, agent_id, agent_name) 
        VALUES (
            'sale',
            product_uuid,
            'Chemise Blanche',
            1,
            120.00,
            120.00,
            120.00,
            'Ahmed Benali',
            '0555123456',
            'ahmed.benali@email.com',
            'completed',
            user_uuid,
            'Agent de Vente'
        )
        ON CONFLICT DO NOTHING;
    END IF;
END $$;

-- Commentaires pour documentation
COMMENT ON TABLE users IS 'Utilisateurs du système (administrateurs et agents de vente)';
COMMENT ON TABLE customers IS 'Base de données des clients de la boutique';
COMMENT ON TABLE products IS 'Catalogue des produits vestimentaires';
COMMENT ON TABLE transactions IS 'Historique de toutes les transactions (ventes et locations)';
COMMENT ON TABLE rentals IS 'Détails spécifiques des locations avec dates et statuts';
COMMENT ON TABLE rental_calendar IS 'Calendrier des réservations pour éviter les conflits';
COMMENT ON TABLE payments IS 'Historique des paiements et versements';

COMMENT ON COLUMN products.barcode IS 'Code-barres du produit pour identification rapide';
COMMENT ON COLUMN products.is_available_for_rental IS 'Indique si le produit peut être loué';
COMMENT ON COLUMN transactions.discount IS 'Pourcentage de réduction appliqué';
COMMENT ON COLUMN transactions.remaining_amount IS 'Montant restant à payer pour les paiements partiels';
COMMENT ON COLUMN rentals.deposit_amount IS 'Montant de la caution pour la location';
COMMENT ON COLUMN payments.payment_method IS 'Méthode de paiement utilisée (espèces, carte, virement)';