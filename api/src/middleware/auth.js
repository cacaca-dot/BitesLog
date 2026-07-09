const jwt = require('jsonwebtoken');
require('dotenv').config();

const verifyToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // "Bearer <token>"

    if (!token) {
        return res.status(401).json({
            status: 'error',
            error: { 
                code: 'NO_TOKEN', 
                message: 'Akses ditolak. Token tidak ditemukan.' 
            }
        });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = decoded; // Tambahkan data user ke request
        next();
    } catch (err) {
        return res.status(401).json({
            status: 'error',
            error: { 
                code: 'INVALID_TOKEN', 
                message: 'Token tidak valid atau kadaluwarsa.' 
            }
        });
    }
};

module.exports = verifyToken;