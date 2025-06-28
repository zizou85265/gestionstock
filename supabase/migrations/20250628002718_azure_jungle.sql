/*
  # Ajout des réductions et versements

  1. Modifications des Tables
    - Ajout de colonnes pour les réductions dans transactions et rentals
    - Nouvelle table `payments` pour gérer les versements
    - Nouvelle table `customers` pour centraliser les informations clients
    - Ajout du mot de passe dans la table users

  2. Sécurité
    - Politiques mises à jour pour les nouvelles fonctionnalités
*/

-- Ajouter la colonne password si elle n'existe pas déjà
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'users' AND column_name = 'password'
  ) THEN
    ALTER TABLE users ADD COLUMN password text DEFAULT '123456';
  END IF;
END $$;

-- Table des clients
CREATE TABLE IF NOT EXISTS customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text NOT NULL,
  email text,
  address text,
  notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE(phone)
);

-- Table des versements
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

-- Ajouter les colonnes de réduction et versement aux transactions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'transactions' AND column_name = 'discount'
  ) THEN
    ALTER TABLE transactions ADD COLUMN discount decimal(5,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'transactions' AND column_name = 'discount_amount'
  ) THEN
    ALTER TABLE transactions ADD COLUMN discount_amount decimal(10,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'transactions' AND column_name = 'paid_amount'
  ) THEN
    ALTER TABLE transactions ADD COLUMN paid_amount decimal(10,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'transactions' AND column_name = 'remaining_amount'
  ) THEN
    ALTER TABLE transactions ADD COLUMN remaining_amount decimal(10,2) DEFAULT 0;
  END IF;
END $$;

-- Ajouter les colonnes de réduction et versement aux rentals
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'rentals' AND column_name = 'discount'
  ) THEN
    ALTER TABLE rentals ADD COLUMN discount decimal(5,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'rentals' AND column_name = 'discount_amount'
  ) THEN
    ALTER TABLE rentals ADD COLUMN discount_amount decimal(10,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'rentals' AND column_name = 'paid_amount'
  ) THEN
    ALTER TABLE rentals ADD COLUMN paid_amount decimal(10,2) DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'rentals' AND column_name = 'remaining_amount'
  ) THEN
    ALTER TABLE rentals ADD COLUMN remaining_amount decimal(10,2) DEFAULT 0;
  END IF;
END $$;

-- Enable RLS sur les nouvelles tables
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Politiques pour customers
CREATE POLICY "Users can read customers" ON customers FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can manage customers" ON customers FOR ALL TO authenticated USING (true);

-- Politiques pour payments
CREATE POLICY "Users can read payments" ON payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can manage payments" ON payments FOR ALL TO authenticated USING (true);

-- Mettre à jour les politiques users pour permettre aux admins de gérer les mots de passe
DROP POLICY IF EXISTS "Allow insert to admins" ON users;
DROP POLICY IF EXISTS "Allow update to admins" ON users;
DROP POLICY IF EXISTS "Allow login by email/password" ON users;
DROP POLICY IF EXISTS "Allow logged-in users to read active users" ON users;

CREATE POLICY "Allow read to authenticated users" ON users FOR SELECT TO authenticated USING (true);
CREATE POLICY "Allow insert to admins" ON users FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Allow update to admins" ON users FOR UPDATE TO authenticated USING (
  EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')
);
CREATE POLICY "Allow login by email/password" ON users FOR SELECT TO anon USING (is_active = true);
CREATE POLICY "Allow logged-in users to read active users" ON users FOR SELECT TO public USING (is_active = true);

-- Trigger pour updated_at sur customers
CREATE TRIGGER update_customers_updated_at BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insérer quelques clients de démonstration
INSERT INTO customers (name, phone, email, address) VALUES
  ('Ahmed Benali', '0555123456', 'ahmed.benali@email.com', 'Alger Centre'),
  ('Fatima Khelifi', '0666789012', 'fatima.khelifi@email.com', 'Oran'),
  ('Mohamed Saidi', '0777345678', 'mohamed.saidi@email.com', 'Constantine')
ON CONFLICT (phone) DO NOTHING;