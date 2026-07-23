const API_URL = 'http://127.0.0.1:3000/api/v1';

async function runTest() {
  try {
    console.log('=== TEST REORDER & UPDATE NOTE (S-17) ===\n');

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

    // 2. Ambil 2 cafe
    res = await fetch(`${API_URL}/cafes`);
    data = await res.json();
    const cafe1 = data.data[0].id;
    const cafe2 = data.data[1].id;
    const cafe3 = data.data[2].id;

    // 3. Buat list
    res = await fetch(`${API_URL}/lists`, {
      method: 'POST',
      headers: authHeaders,
      body: JSON.stringify({ title: 'List S-17 Test', description: 'Testing reorder', is_public: true })
    });
    data = await res.json();
    const listId = data.data.id;
    console.log(`✅ List terbuat: ${listId}`);

    // 4. Tambah 3 cafe
    await fetch(`${API_URL}/lists/${listId}/items`, { method: 'POST', headers: authHeaders, body: JSON.stringify({ cafe_id: cafe1 }) });
    await fetch(`${API_URL}/lists/${listId}/items`, { method: 'POST', headers: authHeaders, body: JSON.stringify({ cafe_id: cafe2 }) });
    await fetch(`${API_URL}/lists/${listId}/items`, { method: 'POST', headers: authHeaders, body: JSON.stringify({ cafe_id: cafe3 }) });
    console.log('✅ 3 Cafe ditambahkan');

    // 5. Update Note cafe2
    await fetch(`${API_URL}/lists/${listId}/items/${cafe2}`, {
      method: 'PUT',
      headers: authHeaders,
      body: JSON.stringify({ note: 'Ini catatan kurator test' })
    });
    console.log('✅ Catatan cafe diupdate');

    // 6. Reorder (3, 1, 2)
    const newOrder = [cafe3, cafe1, cafe2];
    await fetch(`${API_URL}/lists/${listId}/items/reorder`, {
      method: 'PUT',
      headers: authHeaders,
      body: JSON.stringify({ order: newOrder })
    });
    console.log('✅ Reorder dieksekusi (cafe3, cafe1, cafe2)');

    // 7. GET detail and check
    res = await fetch(`${API_URL}/lists/${listId}`, { headers: authHeaders });
    data = await res.json();
    const items = data.data.items;

    let orderBenar = true;
    for (let i = 0; i < items.length; i++) {
      if (items[i].cafe_id !== newOrder[i] || items[i].position !== i) {
        orderBenar = false;
        console.error(`❌ Mismatch pada index ${i}: ekspektasi ${newOrder[i]} pos ${i}, dapat ${items[i].cafe_id} pos ${items[i].position}`);
      }
    }
    
    if (orderBenar) {
      console.log('✅ Verifikasi posisi dan urutan: BERHASIL');
    }

    const noteCafe2 = items.find(i => i.cafe_id === cafe2).note;
    if (noteCafe2 === 'Ini catatan kurator test') {
      console.log('✅ Verifikasi Note: BERHASIL');
    } else {
      console.error(`❌ Note mismatch: dapat ${noteCafe2}`);
    }

    // 8. Hapus list
    await fetch(`${API_URL}/lists/${listId}`, { method: 'DELETE', headers: authHeaders });
    console.log('✅ List dibersihkan');

    console.log('\n=== SELESAI ===');
  } catch (err) {
    console.error('❌ Gagal:', err.message);
  }
}

runTest();
