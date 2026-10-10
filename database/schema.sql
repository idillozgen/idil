-- =====================================================================
-- İDİLİŞKO (idilişko) — KKTC C2C KADIN MODA PAZARI VERİTABANI ŞEMASI
-- Hedef Motor: PostgreSQL 15+ (veya Supabase)
-- =====================================================================

-- 0. TEMİZLİK (Önceden kalma nesneleri güvenle temizle)
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS favorites CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TABLE IF EXISTS offers CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS product_images CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS safe_meetup_points CASCADE;
DROP TABLE IF EXISTS users CASCADE;

DROP TYPE IF EXISTS kktc_city CASCADE;
DROP TYPE IF EXISTS product_condition CASCADE;
DROP TYPE IF EXISTS product_status CASCADE;
DROP TYPE IF EXISTS delivery_method CASCADE;
DROP TYPE IF EXISTS order_status CASCADE;
DROP TYPE IF EXISTS escrow_status CASCADE;
DROP TYPE IF EXISTS offer_status CASCADE;

-- 1. ENUM TİPLERİ (KKTC & MODA ÖZELİNDE)
-- ---------------------------------------------------------------------
CREATE TYPE kktc_city AS ENUM (
    'Lefkoşa',
    'Girne',
    'Mağusa',
    'İskele',
    'Güzelyurt',
    'Lefke'
);

CREATE TYPE product_condition AS ENUM (
    'Etiketli Sıfır',
    'Açılmamış Sıfır',
    'Sadece 1 Kez Giyildi',
    'Çok Az Kullanılmış',
    'Kusursuz İkinci El'
);

CREATE TYPE product_status AS ENUM (
    'active',       -- Vitrinde satışta
    'reserved',     -- Teklif veya sipariş aşamasında bloke
    'sold',         -- Satıldı
    'archived'      -- Satıcı tarafından yayından kaldırıldı
);

CREATE TYPE delivery_method AS ENUM (
    'meetup',       -- Güvenli Noktada Elden Teslim
    'cargo'         -- Ada İçi Kargo (Kargom Kıbrıs)
);

CREATE TYPE order_status AS ENUM (
    'awaiting_payment',     -- Ödeme bekleniyor
    'in_escrow',            -- Para güvenli havuzda bloke, satıcı teslimat hazırlığında
    'shipped',              -- Kargoya verildi / buluşma günü kararlaştırıldı
    'delivered',            -- Alıcıya ulaştı / buluşuldu
    'completed',            -- Alıcı onayladı, bakiye satıcıya aktarıldı
    'disputed',             -- İtiraz / iade süreci başladı
    'cancelled'             -- İptal edildi, para alıcıya iade edildi
);

CREATE TYPE escrow_status AS ENUM (
    'held',                 -- Havuzda kilitli
    'released',             -- Satıcıya serbest bırakıldı
    'refunded'              -- Alıcıya geri ödendi
);

CREATE TYPE offer_status AS ENUM (
    'pending',              -- Satıcı onayı bekliyor
    'accepted',             -- Satıcı kabul etti (indirimli alım hakkı)
    'rejected',             -- Satıcı reddetti
    'expired'               -- Zaman aşımına uğradı (24 saat)
);


-- 2. KULLANICILAR TABLOSU (users)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,      -- KKTC +90 542 / 548 / 533 SMS doğrulaması
    full_name VARCHAR(100) NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE,
    avatar_url TEXT,
    bio TEXT,
    city kktc_city DEFAULT 'Girne',
    campus_name VARCHAR(100),                      -- DAÜ, YDÜ, GAÜ, ODTÜ KKK, UKÜ, LAÜ
    
    -- Güvenlik & Kadın Topluluk Doğrulaması
    is_verified BOOLEAN DEFAULT FALSE,             -- 🛡️ Doğrulanmış Profil Rozeti
    verification_method VARCHAR(50),               -- 'student_id', 'id_card', 'sms'
    verified_at TIMESTAMPTZ,
    
    -- Satıcı Puan & İstatistikleri
    rating_avg NUMERIC(2, 1) DEFAULT 5.0,
    sales_count INT DEFAULT 0,
    follower_count INT DEFAULT 0,
    
    -- İdilişko Cüzdan (Havuz Entegrasyonu)
    wallet_available_balance NUMERIC(10, 2) DEFAULT 0.00,  -- Çekilebilir serbest bakiye (TL)
    wallet_blocked_balance NUMERIC(10, 2) DEFAULT 0.00,    -- Havuzda bekleyen bakiye (TL)
    bank_iban VARCHAR(34),                                 -- KKTC İktisat, Creditwest vb.
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- 3. GÜVENLİ ELDEN TESLİM NOKTALARI (safe_meetup_points)
-- ---------------------------------------------------------------------
CREATE TABLE safe_meetup_points (
    id SERIAL PRIMARY KEY,
    city kktc_city NOT NULL,
    name VARCHAR(150) NOT NULL,                    -- Örn: "Dereboyu Gloria Jean's Önü"
    description TEXT,                              -- "Kamera görüş alanında ve aydınlık ana cadde"
    google_maps_url TEXT,
    is_active BOOLEAN DEFAULT TRUE
);


-- 4. KATEGORİLER TABLOSU (categories)
-- ---------------------------------------------------------------------
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL,                     -- Mezuniyet & Abiye, Günlük Giyim, Çanta vb.
    slug VARCHAR(80) UNIQUE NOT NULL,
    icon VARCHAR(10),                              -- ✨, 👗, 👜, 💄
    parent_id INT REFERENCES categories(id) ON DELETE CASCADE,
    display_order INT DEFAULT 0
);


-- 5. ÜRÜNLER / İLANLAR (products)
-- ---------------------------------------------------------------------
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES categories(id),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    brand VARCHAR(80) NOT NULL,                    -- Zara, Mango, Stradivarius, Bershka...
    size VARCHAR(40) NOT NULL,                     -- S / 36, M / 38, Standart...
    
    -- Kızlar İçin Beden & Kalıp Duruş Alanları
    seller_height VARCHAR(20),                     -- Örn: "1.68 cm"
    seller_weight VARCHAR(20),                     -- Örn: "54 kg"
    fit_style VARCHAR(40) DEFAULT 'Tam Kalıp',     -- Tam Kalıp, Dar Kalıp, Oversize
    
    condition product_condition NOT NULL,
    price NUMERIC(10, 2) NOT NULL,                 -- Satış Fiyatı (TL)
    original_price NUMERIC(10, 2),                 -- Mağaza / Sıfır Fiyatı (TL)
    
    -- Konum & Ada İçi Teslimat Şartları
    city kktc_city NOT NULL,
    meetup_point_id INT REFERENCES safe_meetup_points(id),
    custom_meetup_note TEXT,                       -- Özel buluşma noktası detayı
    allow_safe_meetup BOOLEAN DEFAULT TRUE,        -- Güvenli elden teslim kabul ediyor mu?
    allow_cargo BOOLEAN DEFAULT TRUE,              -- Kargom Kıbrıs (70 TL) kabul ediyor mu?
    allow_trade BOOLEAN DEFAULT FALSE,             -- Takasa açık mı?
    
    status product_status DEFAULT 'active',
    likes_count INT DEFAULT 0,
    views_count INT DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- 6. ÜRÜN FOTOĞRAFLARI (product_images)
-- ---------------------------------------------------------------------
CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    is_cover BOOLEAN DEFAULT FALSE,                -- Vitrin kapak fotoğrafı mı?
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- 7. SİPARİŞLER & HAVUZ HESAP (orders & escrow)
-- ---------------------------------------------------------------------
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_code VARCHAR(30) UNIQUE NOT NULL,        -- Örn: IDL-2026-94812
    buyer_id UUID NOT NULL REFERENCES users(id),
    seller_id UUID NOT NULL REFERENCES users(id),
    product_id UUID NOT NULL REFERENCES products(id),
    
    -- Finansal Tutar Blokesi
    product_amount NUMERIC(10, 2) NOT NULL,
    cargo_fee NUMERIC(10, 2) DEFAULT 0.00,         -- 0 TL (Elden) veya 70 TL (Kargo)
    buyer_protection_fee NUMERIC(10, 2) DEFAULT 0.00,
    seller_commission_fee NUMERIC(10, 2) DEFAULT 0.00,
    total_paid_amount NUMERIC(10, 2) NOT NULL,     -- Alıcı kartından çekilen toplam bloke tutar
    
    -- Lojistik ve Teslimat
    delivery_method delivery_method NOT NULL,
    meetup_point_id INT REFERENCES safe_meetup_points(id),
    cargo_tracking_number VARCHAR(100),            -- Kargom Kıbrıs takip barkodu
    meetup_confirmation_code VARCHAR(10),          -- Elden teslim QR / SMS onay kodu (Örn: "4829")
    
    -- Süreç Durumları
    order_status order_status DEFAULT 'in_escrow',
    escrow_status escrow_status DEFAULT 'held',
    
    escrow_released_at TIMESTAMPTZ,                -- Satıcıya aktarım tarihi
    auto_approval_deadline TIMESTAMPTZ,            -- Teslimden 48 saat sonra otomatik onay
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- 8. TEKLİF & PAZARLIK (offers)
-- ---------------------------------------------------------------------
CREATE TABLE offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    buyer_id UUID NOT NULL REFERENCES users(id),
    seller_id UUID NOT NULL REFERENCES users(id),
    offer_amount NUMERIC(10, 2) NOT NULL,
    status offer_status DEFAULT 'pending',
    expires_at TIMESTAMPTZ NOT NULL,               -- 24 saat sonra süresi dolar
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- 9. MESAJLAŞMA & SOHBET (conversations & messages)
-- ---------------------------------------------------------------------
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES products(id) ON DELETE SET NULL,
    buyer_id UUID NOT NULL REFERENCES users(id),
    seller_id UUID NOT NULL REFERENCES users(id),
    last_message_text TEXT,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (product_id, buyer_id, seller_id)
);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    is_safe_filtered BOOLEAN DEFAULT TRUE,         -- AI içerik filtresinden geçti mi?
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- 10. FAVORİLER & BEĞENİLER (favorites)
-- ---------------------------------------------------------------------
CREATE TABLE favorites (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, product_id)
);


-- 11. DEĞERLENDİRME & YORUMLAR (reviews)
-- ---------------------------------------------------------------------
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID UNIQUE NOT NULL REFERENCES orders(id),
    reviewer_id UUID NOT NULL REFERENCES users(id),
    seller_id UUID NOT NULL REFERENCES users(id),
    rating INT CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);


-- 12. PERFORMANS İNDEKSLERİ (INDEXES)
-- ---------------------------------------------------------------------
CREATE INDEX idx_products_city ON products(city);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_price ON products(price);
CREATE INDEX idx_orders_buyer ON orders(buyer_id);
CREATE INDEX idx_orders_seller ON orders(seller_id);
CREATE INDEX idx_messages_conversation ON messages(conversation_id);


-- =====================================================================
-- BAŞLANGIÇ TOHUM VERİLERİ (KKTC ÖZELİNDE SEED DATA)
-- =====================================================================

-- Güvenli Buluşma Noktaları
INSERT INTO safe_meetup_points (city, name, description) VALUES
('Lefkoşa', 'Dereboyu Gloria Jean''s Önü', 'Merkezi cadde üzeri, güvenlik kameralı ve aydınlık buluşma noktası'),
('Girne', 'Girne Antik Liman Meydanı', 'Turizm Zabıtası yakını, halka açık açık alan'),
('Girne', 'Barış Parkı Kafe Girişi', 'Merkezi park içi kafe önü'),
('Mağusa', 'City Mall AVM Ana Girişi', 'Güvenlikli AVM ana kapısı önü'),
('Mağusa', 'DAÜ Kampüs İçi CL Binası Önü', 'Doğu Akdeniz Üniversitesi Merkezi Derslikler önü'),
('Güzelyurt', 'ODTÜ KKK Ana Nizamiye Girişi', 'ODTÜ Kuzey Kıbrıs Kampüsü nizamiye alanı'),
('Lefke', 'LAÜ Kampüs Meydanı', 'Lefke Avrupa Üniversitesi meydanı'),
('İskele', 'Long Beach Sahil Yolu Kafe Önü', 'Popüler sahil yürüyüş yolu');

-- Kategoriler
INSERT INTO categories (name, slug, icon, display_order) VALUES
('Mezuniyet & Balo Elbiseleri', 'mezuniyet-abiye', '✨', 1),
('Günlük Giyim & Takım', 'giyim', '👗', 2),
('Çanta & Cüzdan', 'canta', '👜', 3),
('Ayakkabı & Sneaker', 'ayakkabi', '👠', 4),
('Orijinal Kozmetik & Bakım', 'kozmetik', '💄', 5),
('Takı & Aksesuar', 'aksesuar', '💍', 6);

-- Örnek Kullanıcılar (Seed Users)
INSERT INTO users (id, phone_number, full_name, username, avatar_url, city, campus_name, is_verified, rating_avg, sales_count) VALUES
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', '+905488000001', 'İdil Özgen', 'idil_kktc', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80', 'Girne', 'GAÜ Kampüs', true, 5.0, 14),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', '+905488000002', 'Melis T.', 'melis_girne', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&q=80', 'Girne', 'GAÜ Kampüs', true, 4.9, 8),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', '+905488000003', 'Selin K.', 'selin_dau', 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=120&q=80', 'Mağusa', 'DAÜ Kampüs', true, 5.0, 5),
('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', '+905488000004', 'Derya B.', 'derya_ydu', 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=120&q=80', 'Lefkoşa', 'YDÜ Kampüs', true, 4.8, 12);

-- Örnek İlanlar (Seed Products)
INSERT INTO products (id, seller_id, category_id, title, brand, size, seller_height, seller_weight, fit_style, condition, price, original_price, city, allow_safe_meetup, allow_cargo) VALUES
('11111111-1111-1111-1111-111111111111', 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 1, 'Zara Saten Abiye Elbise (Zümrüt Yeşili)', 'Zara', 'S / 36', '1.68 cm', '54 kg', 'Tam Kalıp', 'Sadece 1 Kez Giyildi', 1400.00, 2800.00, 'Girne', true, true),
('22222222-2222-2222-2222-222222222222', 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 3, 'Mango Suni Deri Baget Omuz Çantası', 'Mango', 'Standart', '1.65 cm', '52 kg', 'Tam Kalıp', 'Kusursuz İkinci El', 650.00, 1300.00, 'Mağusa', true, true),
('33333333-3333-3333-3333-333333333333', 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 2, 'Bershka Keten Pantolon & Crop Ceket Takım', 'Bershka', 'M / 38', '1.70 cm', '58 kg', 'Tam Kalıp', 'Çok Az Kullanılmış', 850.00, 1900.00, 'Lefkoşa', true, true);

-- Ürün Kapak Görselleri
INSERT INTO product_images (product_id, image_url, is_cover, display_order) VALUES
('11111111-1111-1111-1111-111111111111', 'https://images.unsplash.com/photo-1566174053879-31528523f8ae?auto=format&fit=crop&w=700&q=80', true, 1),
('22222222-2222-2222-2222-222222222222', 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&w=700&q=80', true, 1),
('33333333-3333-3333-3333-333333333333', 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=700&q=80', true, 1);


-- =====================================================================
-- SUPABASE STORAGE & ROW LEVEL SECURITY (RLS) POLİTİKALARI
-- =====================================================================

-- RLS Açma
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE safe_meetup_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;

-- Herkes vitrindeki aktif ürünleri görebilir (Public Read)
CREATE POLICY "Public products viewable" ON products FOR SELECT USING (true);
CREATE POLICY "Public categories viewable" ON categories FOR SELECT USING (true);
CREATE POLICY "Public meetup points viewable" ON safe_meetup_points FOR SELECT USING (true);
CREATE POLICY "Public product images viewable" ON product_images FOR SELECT USING (true);

-- İlan Ekleme ve Teklif Verme İzinleri (Public Insert)
CREATE POLICY "Public insert products" ON products FOR INSERT WITH CHECK (true);
CREATE POLICY "Public insert product_images" ON product_images FOR INSERT WITH CHECK (true);
CREATE POLICY "Public insert orders" ON orders FOR INSERT WITH CHECK (true);
CREATE POLICY "Public insert offers" ON offers FOR INSERT WITH CHECK (true);


