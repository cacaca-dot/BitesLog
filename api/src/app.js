const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// ===== MIDDLEWARE GLOBAL (PALING ATAS!) =====
app.use(cors());
app.use(express.json());  // ← HARUS SEBELUM ROUTES!

// ===== ROUTES =====
const authRoutes = require('./modules/auth/auth.routes');
app.use('/api/v1/auth', authRoutes);

const verifyToken = require('./middleware/auth');
app.get('/api/v1/protected', verifyToken, (req, res) => {
    res.json({ 
        message: `Halo ${req.user.username}, ini data rahasia!` 
    });
});

// ===== HEALTH CHECK =====
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
            database: 'disconnected' 
        });
    }
});

// ===== ERROR HANDLER (PALING AKHIR!) =====
const errorHandler = require('./middleware/errorHandler');
app.use(errorHandler);

// ===== JALANKAN SERVER =====
app.listen(PORT, () => {
    console.log(`🚀 Server berjalan di http://localhost:${PORT}`);
});