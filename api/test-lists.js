// test-lists.js — uji semua endpoint modul Lists BitesLog
// Cara jalanin (dari folder D:\BitesLog\api, server HARUS lagi nyala):
//   node test-lists.js
// Butuh Node 18+ (pakai fetch bawaan).

const BASE = 'http://localhost:3000/api/v1';

// >>> GANTI dengan akun test kamu <<<
const EMAIL = 'ainn';
const PASSWORD = '12345678';

// true  = list uji dihapus lagi di akhir (bersih)
// false = list uji DIBIARKAN biar bisa kamu cek langsung di Neon
const CLEANUP = true;

let pass = 0, fail = 0;
function log(ok, label, extra = '') {
  console.log(`${ok ? '\u2705' : '\u274C'} ${label}${extra ? ' \u2192 ' + extra : ''}`);
  ok ? pass++ : fail++;
}

async function req(method, path, token, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: 'Bearer ' + token } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  let data = null;
  try { data = await res.json(); } catch (_) {}
  return { status: res.status, data };
}

(async () => {
  console.log('\n=== UJI MODUL LISTS (S-15/16/17) ===\n');

  // 1. Login -> ambil token
  const login = await req('POST', '/auth/login', null, { identifier: EMAIL, password: PASSWORD });
  const token = login.data && login.data.data && login.data.data.token;
  log(login.status === 200 && !!token, 'Login', `status ${login.status}`);
  if (!token) { console.log('\n\u26D4 Login gagal \u2014 cek EMAIL & PASSWORD di atas. Berhenti.\n'); return; }

  // 2. Ambil 1 cafe buat bahan uji
  const cafes = await req('GET', '/cafes', token);
  const cafeId = cafes.data && cafes.data.data && cafes.data.data[0] && cafes.data.data[0].id;
  log(cafes.status === 200 && !!cafeId, 'Ambil cafe contoh', cafeId || 'DB cafe kosong');
  if (!cafeId) { console.log('\n\u26D4 Nggak ada cafe di DB buat dites. Berhenti.\n'); return; }

  // 3. Buat list baru
  const create = await req('POST', '/lists', token, {
    title: 'List Uji Otomatis', description: 'dibuat oleh test-lists.js', is_public: true,
  });
  const listId = create.data && create.data.data && create.data.data.id;
  log([200, 201].includes(create.status) && !!listId, 'POST buat list', `status ${create.status}, id ${listId}`);
  if (!listId) { console.log('\n\u26D4 Gagal buat list. Cek log server (mungkin query/kolom salah).\n'); return; }

  // 4. Tambah cafe ke list
  const addItem = await req('POST', `/lists/${listId}/items`, token, { cafe_id: cafeId, note: 'catatan uji' });
  log([200, 201].includes(addItem.status), 'POST tambah cafe ke list', `status ${addItem.status}`);

  // 5. GET /lists/me  <-- CEK PENTING: route "me" nggak boleh ketangkap sama :id
  const mine = await req('GET', '/lists/me', token);
  const row = Array.isArray(mine.data && mine.data.data) ? mine.data.data.find(l => l.id === listId) : null;
  log(mine.status === 200 && !!row, 'GET /lists/me (list muncul)',
      `status ${mine.status}, cafe_count ${row ? row.cafe_count : '-'}`);

  // 6. GET detail + isi cafe
  const detail = await req('GET', `/lists/${listId}`, token);
  const d = detail.data && detail.data.data;
  const items = d && (d.cafes || d.items || d.list_items) || [];
  log(detail.status === 200 && items.length > 0, 'GET /lists/:id (detail + isi cafe)',
      `status ${detail.status}, jumlah item ${items.length}`);

  // 7. Update list
  const upd = await req('PUT', `/lists/${listId}`, token, { title: 'List Uji (Updated)', is_public: false });
  log(upd.status === 200, 'PUT update list', `status ${upd.status}`);

  // 8. GET /lists/saved (harus 200 walau kosong)
  const saved = await req('GET', '/lists/saved', token);
  log(saved.status === 200, 'GET /lists/saved', `status ${saved.status}`);

  // 9. Hapus cafe dari list
  const delItem = await req('DELETE', `/lists/${listId}/items/${cafeId}`, token);
  log([200, 204].includes(delItem.status), 'DELETE cafe dari list', `status ${delItem.status}`);

  // 10. Cleanup (opsional)
  if (CLEANUP) {
    const delList = await req('DELETE', `/lists/${listId}`, token);
    log([200, 204].includes(delList.status), 'DELETE list (cleanup)', `status ${delList.status}`);
  } else {
    console.log(`\u2139\uFE0F  List uji DIBIARKAN (id ${listId}) \u2014 cek di tabel lists Neon.`);
  }

  console.log(`\n=== SELESAI: ${pass} lulus, ${fail} gagal ===\n`);
})();
