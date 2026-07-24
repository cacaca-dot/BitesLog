const { Pool } = require('pg');
require('dotenv').config();

const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
});

async function migrate() {
    try {
        console.log('🔄 Menjalankan migrasi database...');
        
        // Tambahkan parent_comment_id jika belum ada (idempotent)
        await pool.query(`
            ALTER TABLE comments 
            ADD COLUMN IF NOT EXISTS parent_comment_id UUID NULL REFERENCES comments(id) ON DELETE CASCADE;
        `);
        
        // Buat tabel notifications
        await pool.query(`
            CREATE TABLE IF NOT EXISTS notifications (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                actor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                type VARCHAR(50) NOT NULL,
                target_type VARCHAR(50),
                target_id UUID,
                is_read BOOLEAN DEFAULT false,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        `);
        
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_notifications_user_id_created_at 
            ON notifications(user_id, created_at DESC);
        `);
        
        await pool.query(`
            ALTER TABLE notifications 
            ADD COLUMN IF NOT EXISTS comment_id UUID NULL REFERENCES comments(id) ON DELETE CASCADE;
        `);
        
        // Buat tabel saved_lists
        await pool.query(`
            CREATE TABLE IF NOT EXISTS saved_lists (
                user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY(user_id, list_id)
            );
        `);

        // Update CHECK constraint for price_range in cafes
        await pool.query(`
            DO $do$
            BEGIN
                ALTER TABLE cafes DROP CONSTRAINT IF EXISTS cafes_price_range_check;
                ALTER TABLE cafes ADD CONSTRAINT cafes_price_range_check CHECK (price_range = ANY (ARRAY['$', '$$', '$$$', '$$$$']::text[]));
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE 'Gagal update constraint price_range: %', SQLERRM;
            END $do$;
        `);

        // Update struktur tabel cafes (kategori multi, area, dan hapus category lama)
        await pool.query(`
            ALTER TABLE cafes 
            ADD COLUMN IF NOT EXISTS categories TEXT[] DEFAULT '{}',
            ADD COLUMN IF NOT EXISTS area TEXT;
        `);

        await pool.query(`
            ALTER TABLE cafes DROP COLUMN IF EXISTS category;
        `);

        await pool.query(`
            DO $do$
            BEGIN
                ALTER TABLE cafes DROP CONSTRAINT IF EXISTS cafes_categories_check;
                ALTER TABLE cafes ADD CONSTRAINT cafes_categories_check 
                CHECK (categories <@ ARRAY['Kopi','Non-Kopi','Dessert','Roti','Kue','Makanan Berat','Brunch','Lainnya']::text[]);
            EXCEPTION
                WHEN OTHERS THEN
                    RAISE NOTICE 'Gagal update constraint categories: %', SQLERRM;
            END $do$;
        `);

        // Drop priority column dari watchlist
        await pool.query(`
            ALTER TABLE watchlist DROP COLUMN IF EXISTS priority;
        `);

        // Buat tabel visit_photos
        await pool.query(`
            CREATE TABLE IF NOT EXISTS visit_photos (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                visit_id UUID NOT NULL REFERENCES visits(id) ON DELETE CASCADE,
                url TEXT NOT NULL,
                "position" INT NOT NULL DEFAULT 0,
                created_at TIMESTAMPTZ DEFAULT now()
            );
        `);
        
        await pool.query(`
            CREATE INDEX IF NOT EXISTS idx_visit_photos_visit_id ON visit_photos(visit_id);
        `);
        
        // Migrasi data lama (idempotent)
        await pool.query(`
            INSERT INTO visit_photos (visit_id, url, "position") 
            SELECT id, photo_path, 0 FROM visits v 
            WHERE photo_path IS NOT NULL AND NOT EXISTS (
                SELECT 1 FROM visit_photos vp WHERE vp.visit_id = v.id
            );
        `);

        console.log('✅ Migrasi sukses: Kolom parent_comment_id, tabel notifications, tabel saved_lists, constraint price_range, watchlist, visit_photos, dan categories/area selesai.');
    } catch (err) {
        console.error('❌ Gagal menjalankan migrasi:', err);
    } finally {
        await pool.end();
    }
}

migrate();
