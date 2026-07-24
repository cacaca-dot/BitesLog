const { Pool } = require('pg');
require('dotenv').config();

const dns = require('dns');
dns.setDefaultResultOrder('ipv4first');

const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
});

pool.on('connect', () => {
    console.log('✅ Database PostgreSQL connected');
});

pool.on('error', (err) => {
    console.error('❌ Database connection error', err);
});

module.exports = pool;