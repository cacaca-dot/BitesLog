const authService = require('./auth.service');
const { success } = require('../../utils/response');

const register = async (req, res, next) => {
    try {
        const { full_name, username, email, password, confirm_password } = req.body;

        // Validasi input
        const errors = [];
        if (!full_name || full_name.length < 2) 
            errors.push('Nama lengkap minimal 2 karakter');
        if (!username || !/^[A-Za-z0-9_]{3,20}$/.test(username)) 
            errors.push('Username 3-20 karakter (huruf, angka, underscore)');
        if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) 
            errors.push('Format email tidak valid');
        if (!password || password.length < 8) 
            errors.push('Password minimal 8 karakter');
        if (password !== confirm_password) 
            errors.push('Password dan konfirmasi tidak sama');

        if (errors.length > 0) {
            return res.status(422).json({
                status: 'error',
                error: { code: 'VALIDATION_ERROR', message: errors.join('. ') }
            });
        }

        await authService.register(full_name, username, email, password);
        return success(res, 201, 'User registered successfully');
    } catch (err) {
        next(err);
    }
};

const login = async (req, res, next) => {
    try {
        const { identifier, password } = req.body;

        if (!identifier || !password) {
            return res.status(422).json({
                status: 'error',
                error: { 
                    code: 'VALIDATION_ERROR', 
                    message: 'Email/username dan password harus diisi' 
                }
            });
        }

        const data = await authService.login(identifier, password);
        return success(res, 200, 'Login berhasil', data);
    } catch (err) {
        next(err);
    }
};

module.exports = { register, login };