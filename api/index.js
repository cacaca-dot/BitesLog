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
app.listen(PORT, () => console.log(`Server jalan di http://localhost:${PORT}`));