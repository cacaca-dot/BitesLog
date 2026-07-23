const http = require('http');

const API_BASE = 'http://localhost:3000/api/v1';

async function req(method, endpoint, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(API_BASE + endpoint);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json'
      }
    };
    if (token) options.headers['Authorization'] = 'Bearer ' + token;

    const request = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data || '{}') });
        } catch(e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    request.on('error', reject);
    if (body) request.write(JSON.stringify(body));
    request.end();
  });
}

async function runTest() {
  console.log('=== TEST LOG VISIT (S-10) ===\n');

  try {
    // 1. Login
    const loginRes = await req('POST', '/auth/login', {
      identifier: 'dimas@mail.com', // user from biteslog.sql
      password: 'password123'       // typical dev password
    });
    
    // If login fails, try another known user
    let token = loginRes.body.token;
    if (!token) {
      const loginRes2 = await req('POST', '/auth/login', {
        identifier: 'kikoyu@mail.com',
        password: 'password123'
      });
      token = loginRes2.body.token;
    }

    if (!token) {
      console.log('❌ Gagal login. Pastikan server nyala dan user ada.');
      return;
    }
    console.log('✅ Login berhasil\n');

    // 2. Cari cafe
    const cafesRes = await req('GET', '/cafes?search=Kopi', null, token);
    const cafes = cafesRes.body.data || [];
    
    if (cafes.length === 0) {
      console.log('❌ Tidak ada cafe untuk dites.');
      return;
    }
    
    const cafe = cafes[0];
    const cafeId = cafe.id;
    console.log(`Pilih cafe: ${cafe.name} (ID: ${cafeId}), Avg Rating awal: ${cafe.avg_rating}, Visit Count awal: ${cafe.visit_count}`);

    // 3. Test insert valid
    console.log('\n--- Test 1: Insert Valid ---');
    const validRes = await req('POST', '/visits', {
      cafe_id: cafeId,
      rating: 4.5,
      review: 'Mantap kopinya',
      favorite_drink: 'Ice Americano',
      price: 35000,
      notes: 'Datang pas sepi'
    }, token);

    if (validRes.status === 201) {
      console.log('✅ Visit berhasil dicatat!');
      console.log(validRes.body.data);
    } else {
      console.log('❌ Gagal catat visit:', validRes.body);
    }

    // 4. Test insert invalid (tanpa rating dan review)
    console.log('\n--- Test 2: Insert Invalid (Tanpa Rating & Review) ---');
    const invalidRes = await req('POST', '/visits', {
      cafe_id: cafeId,
      favorite_drink: 'Kosong'
    }, token);

    if (invalidRes.status === 400 || invalidRes.status === 422) {
      console.log('✅ Validasi jalan! Ditolak karena rating/review kosong.');
    } else {
      console.log('❌ Gagal validasi:', invalidRes.status, invalidRes.body);
    }

    // 5. Verifikasi avg_rating dan visit_count
    console.log('\n--- Test 3: Verifikasi avg_rating ---');
    const cafeDetailRes = await req('GET', `/cafes/${cafeId}`, null, token);
    const cafeDetail = cafeDetailRes.body.data;
    console.log(`Avg Rating sekarang: ${cafeDetail.avg_rating}, Visit Count: ${cafeDetail.visit_count}`);
    
    if (cafeDetail.visit_count > cafe.visit_count) {
      console.log('✅ Recalculate rating sukses via trigger!');
    } else {
      console.log('❌ Visit count tidak nambah!');
    }

  } catch (err) {
    console.error('Error:', err.message);
  }
}

runTest();
