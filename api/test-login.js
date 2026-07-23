// Jika menggunakan Node 18+, fetch sudah bawaan
async function testLogin() {
    try {
        console.log("Memulai test POST ke API Login...");
        const response = await fetch('http://localhost:3000/api/v1/auth/login', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                identifier: "ainn", // Ganti dengan username/email yang sudah didaftarkan
                password: "12345678" // Ganti dengan password yang sesuai
            })
        });

        const data = await response.json();

        console.log("Status Code:", response.status);
        console.log("Response Body:");
        console.log(JSON.stringify(data, null, 2));

    } catch (error) {
        console.error("Gagal menghubungi server:", error);
    }
}

testLogin();
