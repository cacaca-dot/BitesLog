const express = require("express");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

// route tes — buat ngecek server hidup atau nggak
app.get("/health", (req, res) => {
  res.json({ status: "ok", message: "BitesLog API jalan! 🚀" });
});

const PORT = process.env.PORT || 3000;
const pool = require("./db");

// route tes koneksi database
app.get("/db-test", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW()");
    res.json({ status: "ok", waktu_server_db: result.rows[0].now });
  } catch (err) {
    res.status(500).json({ status: "error", pesan: err.message });
  }
});
app.listen(PORT, () => console.log(`Server jalan di http://localhost:${PORT}`));