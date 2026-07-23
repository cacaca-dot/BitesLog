const API_URL = 'http://127.0.0.1:3000/api/v1';

async function runTest() {
  try {
    console.log('=== TEST ADD CAFE (S-07) ===\n');

    // 1. Login
    let res = await fetch(`${API_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier: 'ainn', password: '12345678' })
    });
    let data = await res.json();
    const token = data.data ? data.data.token : data.token;
    if (!token) throw new Error('Login gagal, token tidak ditemukan');
    console.log('✅ Login berhasil');

    const authHeaders = { 
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}` 
    };

    // 2. Add a new cafe
    res = await fetch(`${API_URL}/cafes`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({
        name: 'Test Cafe Duplicate',
        category: 'Coffee',
        city: 'Jakarta',
        price_range: '$$',
        image_url: null,
      })
    });
    data = await res.json();
    console.log('✅ Cafe 1 berhasil ditambahkan:', data.data.name);

    // 3. Add a similar cafe to trigger duplicate flag
    res = await fetch(`${API_URL}/cafes`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({
        name: 'Test cafe Duplicat', // Similar name
        category: 'Dessert',
        city: 'Jakarta',
        price_range: '$$$',
        image_url: 'http://example.com/image.jpg',
      })
    });
    data = await res.json();
    console.log('✅ Cafe 2 ditambahkan dengan status:', res.status);
    
    if (data.possible_duplicates && data.possible_duplicates.length > 0) {
      console.log('✅ Duplicate terdeteksi (Soft check sukses):', data.possible_duplicates);
    } else {
      console.error('❌ Soft duplicate check gagal (array kosong)');
    }

    console.log('\n=== SELESAI ===');
  } catch (err) {
    console.error('❌ Gagal:', err.message);
  }
}

runTest();
