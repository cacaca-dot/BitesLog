const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const authRepository = require('./auth.repository');
require('dotenv').config();

const SALT_ROUNDS = 10;

const register = async (fullName, username, email, password) => {
    // 1. Cek duplikat email
    const existingEmail = await authRepository.findUserByEmail(email);
    if (existingEmail) {
        const error = new Error('Email sudah digunakan');
        error.code = 'EMAIL_TAKEN';
        error.statusCode = 409;
        throw error;
    }

    // 2. Cek duplikat username
    const existingUsername = await authRepository.findUserByUsername(username);
    if (existingUsername) {
        const error = new Error('Username sudah digunakan');
        error.code = 'USERNAME_TAKEN';
        error.statusCode = 409;
        throw error;
    }

    // 3. Hash password
    const passwordHash = await bcrypt.hash(password, SALT_ROUNDS);

    // 4. Simpan user baru
    const newUser = await authRepository.createUser(fullName, username, email, passwordHash);
    return newUser;
};

const login = async (identifier, password) => {
    // 1. Cari user
    const user = await authRepository.findUserByEmailOrUsername(identifier);
    if (!user) {
        const error = new Error('Email/username atau password salah');
        error.code = 'INVALID_CREDENTIALS';
        error.statusCode = 401;
        throw error;
    }

    // 2. Verifikasi password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
        const error = new Error('Email/username atau password salah');
        error.code = 'INVALID_CREDENTIALS';
        error.statusCode = 401;
        throw error;
    }

    // 3. Generate JWT token
    const token = jwt.sign(
        { id: user.id, username: user.username },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );

    return {
        token,
        user: {
            id: user.id,
            username: user.username,
        }
    };
};

module.exports = { register, login };