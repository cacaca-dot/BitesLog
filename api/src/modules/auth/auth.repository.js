const pool = require('../../config/db');

const findUserByEmailOrUsername = async (identifier) => {
    const query = 'SELECT * FROM users WHERE email = $1 OR username = $1';
    const result = await pool.query(query, [identifier]);
    return result.rows[0];
};

const findUserByEmail = async (email) => {
    const query = 'SELECT * FROM users WHERE email = $1';
    const result = await pool.query(query, [email]);
    return result.rows[0];
};

const findUserByUsername = async (username) => {
    const query = 'SELECT * FROM users WHERE username = $1';
    const result = await pool.query(query, [username]);
    return result.rows[0];
};

const createUser = async (fullName, username, email, passwordHash) => {
    const query = `
        INSERT INTO users (full_name, username, email, password_hash)
        VALUES ($1, $2, $3, $4)
        RETURNING id, full_name, username, email, created_at
    `;
    const values = [fullName, username, email, passwordHash];
    const result = await pool.query(query, values);
    return result.rows[0];
};

module.exports = {
    findUserByEmailOrUsername,
    findUserByEmail,
    findUserByUsername,
    createUser
};