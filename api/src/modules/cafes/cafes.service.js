const repo = require('./cafes.repository');
const { canViewContent } = require('../../utils/privacy.helper');

async function searchCafes({ search, categories, areas, city, min_rating, price_range }) {
  return await repo.findCafes({ search, categories, areas, city, min_rating, price_range });
}

async function getFilters() {
  return await repo.getFilters();
}

async function getCafeDetail(cafeId, userId = null) {
  const cafe = await repo.findCafeById(cafeId, userId);
  if (!cafe) {
    throw new Error('Cafe tidak ditemukan');
  }
  return cafe;
}

async function addCafe(cafeData, userId, force = false) {
  if (!cafeData.name || cafeData.name.trim().length === 0) {
    throw new Error('Nama cafe wajib diisi');
  }

  // Validasi price_range
  let validPriceRange = null;
  if (['$', '$$', '$$$', '$$$$'].includes(cafeData.price_range)) {
    validPriceRange = cafeData.price_range;
  }

  // Soft duplicate check
  let possibleDuplicates = [];
  if (cafeData.city) {
    const cleanCity = cafeData.city.replace(/\\s+(City|Regency)$/i, '').replace(/^(Kota|Kabupaten)\\s+/i, '').trim();
    possibleDuplicates = await repo.findSimilarCafes(cafeData.name, cleanCity, cafeData.latitude, cafeData.longitude);
  }

  if (possibleDuplicates.length > 0 && !force) {
    const error = new Error('Kandidat duplikat ditemukan');
    error.code = 'DUPLICATE_CAFE_CANDIDATES';
    error.candidates = possibleDuplicates;
    throw error;
  }

  const cafe = await repo.createCafe({
    ...cafeData,
    price_range: validPriceRange,
    created_by: userId
  });

  return { cafe };
}

async function getCafeReviews(cafeId, currentUserId) {
  // Verifikasi cafe ada
  await getCafeDetail(cafeId);
  return await repo.findCafeReviews(cafeId, currentUserId);
}

async function getCafePhotos(cafeId, viewerId) {
  await getCafeDetail(cafeId);
  const photos = await repo.getCafePhotos(cafeId);

  const filteredPhotos = [];
  for (const photo of photos) {
    const canView = await canViewContent(viewerId, photo.user_id);
    if (canView) {
      filteredPhotos.push(photo);
    }
  }
  return filteredPhotos;
}

module.exports = {
  searchCafes,
  getFilters,
  getCafeDetail,
  addCafe,
  getCafeReviews,
  getCafePhotos
};