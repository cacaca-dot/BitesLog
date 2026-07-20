// src/modules/discovery/discovery.service.js
const repo = require('./discovery.repository');

// ============================================
// SEARCH
// ============================================

async function searchAll(keyword) {
  if (!keyword || keyword.trim().length === 0) {
    return { cafes: [], users: [], lists: [] };
  }

  const [cafes, users, lists] = await Promise.all([
    repo.searchCafes(keyword.trim()),
    repo.searchUsers(keyword.trim()),
    repo.searchLists(keyword.trim())
  ]);

  return { cafes, users, lists };
}

// ============================================
// DISCOVER
// ============================================

async function getDiscover(userId) {
  // 1. Popular cafes
  const popular = await repo.getPopularCafes(10);

  // 2. Top rated cafes
  const topRated = await repo.getTopRatedCafes(10);

  // 3. Rekomendasi personal (berdasarkan kategori favorit)
  let recommendations = [];
  const favoriteCategories = await repo.getUserFavoriteCategories(userId);
  
  if (favoriteCategories.length > 0) {
    const topCategory = favoriteCategories[0].category;
    recommendations = await repo.getCafesByCategory(topCategory, userId, 10);
  }

  // 4. Cafe yang dikunjungi teman yang di-follow
  const fromFollowing = await repo.getCafesVisitedByFollowing(userId, 10);

  return {
    popular,
    topRated,
    recommendations,
    fromFollowing,
    favoriteCategories
  };
}

module.exports = {
  searchAll,
  getDiscover
};