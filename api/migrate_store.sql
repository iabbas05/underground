-- Healthy-food store: products, daily per-branch stock (entered by staff), pickup orders (pay on pickup).
--   npx wrangler d1 execute ug-admin --remote --file=migrate_store.sql
CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL, name_ar TEXT NOT NULL,
  descr TEXT, descr_ar TEXT,
  category TEXT NOT NULL DEFAULT 'meal',      -- meal | snack | drink | supplement
  price REAL NOT NULL,
  calories INTEGER, protein INTEGER, carbs INTEGER, fat INTEGER,   -- per serving
  tags TEXT NOT NULL DEFAULT '',              -- comma list: high-protein,low-carb,vegetarian,gluten-free
  active INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS product_stock (
  product_id INTEGER NOT NULL REFERENCES products(id),
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  date TEXT NOT NULL,                         -- YYYY-MM-DD (Bahrain)
  qty INTEGER NOT NULL,
  PRIMARY KEY (product_id, branch_id, date)
);
CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL REFERENCES accounts(id),
  branch_id INTEGER NOT NULL REFERENCES branches(id),
  pickup_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',     -- pending | approved | ready | picked | rejected | cancelled
  total REAL NOT NULL,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_orders_branch ON orders(branch_id, pickup_date, status);
CREATE INDEX IF NOT EXISTS idx_orders_acc ON orders(account_id, id);
CREATE TABLE IF NOT EXISTS order_items (
  order_id INTEGER NOT NULL REFERENCES orders(id),
  product_id INTEGER NOT NULL REFERENCES products(id),
  qty INTEGER NOT NULL,
  price REAL NOT NULL,
  name TEXT NOT NULL, name_ar TEXT NOT NULL
);

-- Sample menu (prices are placeholders: edit them in the back office)
INSERT INTO products (name,name_ar,descr,descr_ar,category,price,calories,protein,carbs,fat,tags) VALUES
 ('Grilled chicken & rice bowl','بول دجاج مشوي مع رز','Grilled chicken breast, brown rice, steamed vegetables','صدر دجاج مشوي مع رز بني وخضار مطبوخة على البخار','meal',2.500,520,45,50,12,'high-protein'),
 ('Beef & sweet potato','لحم مع بطاطا حلوة','Lean beef strips, roasted sweet potato, greens','شرائح لحم قليل الدهن مع بطاطا حلوة مشوية وخضار','meal',3.200,580,42,48,20,'high-protein'),
 ('Salmon & quinoa','سلمون مع كينوا','Baked salmon, quinoa, avocado salad','سلمون مخبوز مع كينوا وسلطة أفوكادو','meal',3.800,610,38,40,30,'high-protein,gluten-free'),
 ('Tuna salad (low carb)','سلطة تونة (قليلة الكربوهيدرات)','Tuna, mixed greens, egg, olive oil','تونة مع خضار ورقية وبيض وزيت زيتون','meal',2.200,320,34,8,16,'low-carb,high-protein,gluten-free'),
 ('Veggie falafel wrap','لفافة فلافل نباتية','Baked falafel, hummus, fresh veggies, whole wheat wrap','فلافل مخبوزة مع حمص وخضار طازجة في خبز قمح كامل','meal',1.800,430,16,58,14,'vegetarian'),
 ('Protein oats','شوفان بالبروتين','Oats, whey, banana, peanut butter','شوفان مع واي وموز وزبدة فول سوداني','snack',1.500,380,28,45,9,'high-protein,vegetarian'),
 ('Greek yogurt & berries','زبادي يوناني مع توت','High-protein yogurt, mixed berries, honey','زبادي يوناني عالي البروتين مع توت وعسل','snack',1.200,210,18,24,4,'high-protein,vegetarian'),
 ('Protein bar','بار بروتين','20g protein, low sugar','20 جم بروتين وسكر قليل','snack',1.000,220,20,18,8,'high-protein'),
 ('Protein shake','شيك بروتين','Whey, milk, banana','واي مع حليب وموز','drink',1.800,280,30,22,6,'high-protein'),
 ('Fresh orange juice','عصير برتقال طازج','No added sugar','بدون سكر مضاف','drink',1.000,110,2,26,0,'vegetarian,gluten-free'),
 ('Water 500ml','ماء 500 مل','','','drink',0.200,0,0,0,0,'');
