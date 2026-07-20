const repo = require('./cafes.repository');

async function searchCafes({ search, category, city }) {
  return await repo.findCafes(search, category, city);
}

async function getCafeDetail(cafeId) {
  const cafe = await repo.findCafeById(cafeId);
  if (!cafe) {
    throw new Error('Cafe tidak ditemukan');
  }
  return cafe;
}

async function addCafe(cafeData, userId) {
  if (!cafeData.name || cafeData.name.trim().length === 0) {
    throw new Error('Nama cafe wajib diisi');
  }

  const cafe = await repo.createCafe({
    ...cafeData,
    created_by: userId
  });

  return { duplicate: false, cafe };
}

module.exports = {
  searchCafes,
  getCafeDetail,
  addCafe
};