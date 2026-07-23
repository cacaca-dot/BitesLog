// src/app.js
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// MIDDLEWARE GLOBAL (PALING ATAS!)
// ============================================
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// ============================================
// ROUTES
// ============================================

// 1. AUTH ROUTES
console.log('📦 Loading auth routes...');
const authRoutes = require('./modules/auth/auth.routes');
app.use('/api/v1/auth', authRoutes);
console.log('✅ Auth routes loaded');

// 2. CAFE ROUTES
console.log('📦 Loading cafe routes...');
const cafeRoutes = require('./modules/cafes/cafes.routes');
app.use('/api/v1/cafes', cafeRoutes);
console.log('✅ Cafe routes loaded');

// 3. VISIT ROUTES
console.log('📦 Loading visit routes...');
const visitRoutes = require('./modules/visits/visits.routes');
app.use('/api/v1/visits', visitRoutes);
console.log('✅ Visit routes loaded');

// 4. SOCIAL ROUTES
console.log('📦 Loading social routes...');
const socialRoutes = require('./modules/social/social.routes');
app.use('/api/v1', socialRoutes);  // ← Pakai /api/v1 langsung
console.log('✅ Social routes loaded');

// 5.  DISCOVERY ROUTES 
console.log('📦 Loading discovery routes...');
const discoveryRoutes = require('./modules/discovery/discovery.routes');
app.use('/api/v1', discoveryRoutes);
console.log('✅ Discovery routes loaded');

// 6. WATCHLIST ROUTES
console.log('📦 Loading watchlist routes...');
const watchlistRoutes = require('./modules/watchlist/watchlist.routes');
app.use('/api/v1/watchlist', watchlistRoutes);
console.log('✅ Watchlist routes loaded');

// 7. PROFILE ROUTES
console.log('📦 Loading profile routes...');
const profileRoutes = require('./modules/profile/profile.routes');
app.use('/api/v1', profileRoutes);  // ← Pakai /api/v1 langsung
console.log('✅ Profile routes loaded');

// 8. LISTS ROUTES
console.log('📦 Loading lists routes...');
const listRoutes = require('./modules/lists/lists.routes');
app.use('/api/v1/lists', listRoutes);
console.log('✅ Lists routes loaded');

// 9. NOTIFICATIONS ROUTES
console.log('📦 Loading notifications routes...');
const notificationsRoutes = require('./modules/notifications/notifications.routes');
app.use('/api/v1/notifications', notificationsRoutes);
console.log('✅ Notifications routes loaded');

// 8. UPLOADS ROUTE
const verifyToken = require('./middleware/auth');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');

// Buat folder uploads jika belum ada
const uploadsDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}
app.use('/uploads', express.static(uploadsDir));

app.post('/api/v1/uploads', verifyToken, (req, res) => {
    try {
        const { image_base64 } = req.body;
        if (!image_base64) {
            return res.status(400).json({ error: { message: 'image_base64 wajib diisi' } });
        }

        // Format data URI: "data:image/jpeg;base64,/9j/4AAQSk..."
        const matches = image_base64.match(/^data:image\/([A-Za-z-+\/]+);base64,(.+)$/);
        let ext = 'jpg';
        let base64Data = image_base64;

        if (matches && matches.length === 3) {
            ext = matches[1];
            base64Data = matches[2];
        }

        // Khusus "jpeg" jadi "jpg"
        if (ext === 'jpeg') ext = 'jpg';

        const buffer = Buffer.from(base64Data, 'base64');
        const filename = `${crypto.randomUUID()}.${ext}`;
        const filepath = path.join(uploadsDir, filename);

        fs.writeFileSync(filepath, buffer);

        // Untuk localhost bisa pakai req.protocol + req.get('host')
        const url = `${req.protocol}://${req.get('host')}/uploads/${filename}`;

        res.json({
            data: { url },
            message: 'Upload berhasil'
        });
    } catch (err) {
        res.status(500).json({ error: { message: 'Gagal upload foto: ' + err.message } });
    }
});

// 9. PROTECTED TEST ROUTE
app.get('/api/v1/protected', verifyToken, (req, res) => {
    res.json({ 
        message: `Halo ${req.user.username}, ini data rahasia!` 
    });
});

// ============================================
// HEALTH CHECK
// ============================================
app.get('/health', async (req, res) => {
    try {
        const pool = require('./config/db');
        await pool.query('SELECT 1');
        res.json({ 
            status: 'OK', 
            database: 'connected', 
            timestamp: new Date().toISOString() 
        });
    } catch (err) {
        res.status(500).json({ 
            status: 'error', 
            database: 'disconnected',
            message: err.message
        });
    }
});

// ============================================
// ROOT ROUTE
// ============================================
app.get('/', (req, res) => {
    res.json({
        name: 'BitesLog API',
        version: '1.0.0',
        endpoints: {
            health: '/health',
            auth: '/api/v1/auth',
            cafes: '/api/v1/cafes',
            visits: '/api/v1/visits',
            protected: '/api/v1/protected'
        }
    });
});

// ============================================
// ERROR HANDLER (PALING AKHIR!)
// ============================================
const errorHandler = require('./middleware/errorHandler');
app.use(errorHandler);

// ============================================
// JALANKAN SERVER
// ============================================
app.listen(PORT, () => {
    console.log(`\n🚀 Server berjalan di http://localhost:${PORT}`);
    console.log(`📊 Health: http://localhost:${PORT}/health`);
    console.log(`🧪 Test: http://localhost:${PORT}/test`);
    console.log(`🔐 Auth: http://localhost:${PORT}/api/v1/auth`);
    console.log(`☕ Cafes: http://localhost:${PORT}/api/v1/cafes`);
    console.log(`📝 Visits: http://localhost:${PORT}/api/v1/visits`);
    console.log(`📰 Feed: http://localhost:${PORT}/api/v1/feed`);
    console.log(`👥 Follow: http://localhost:${PORT}/api/v1/users/:id/follow`);
    console.log(`❤️ Likes: http://localhost:${PORT}/api/v1/likes`);
    console.log(`💬 Comments: http://localhost:${PORT}/api/v1/comments`);
    console.log(`🔍 Search: http://localhost:${PORT}/api/v1/search`);
    console.log(`🌟 Discover: http://localhost:${PORT}/api/v1/discover`);
    console.log(`👤 Profile: http://localhost:${PORT}/api/v1/users/:id/profile`);
    console.log(`📊 My Stats: http://localhost:${PORT}/api/v1/me/stats`);
    console.log(`📚 Lists: http://localhost:${PORT}/api/v1/lists\n`);
});

