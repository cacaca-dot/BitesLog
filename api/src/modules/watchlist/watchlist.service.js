const repo = require('./watchlist.repository');

async function getWatchlist(userId) {
  return await repo.getWatchlist(userId);
}

async function addToWatchlist(userId, cafeId) {
  return await repo.addToWatchlist(userId, cafeId);
}

async function removeFromWatchlist(userId, cafeId) {
  const result = await repo.removeFromWatchlist(userId, cafeId);
  if (!result) {
    throw new Error('Cafe tidak ditemukan di watchlist');
  }
  return result;
}

module.exports = {
  getWatchlist,
  addToWatchlist,
  removeFromWatchlist
};
