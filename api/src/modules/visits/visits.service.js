const repo = require('./visits.repository');

async function getUserDiary(userId) {
  return await repo.findVisitsByUser(userId);
}

async function getVisitDetail(visitId) {
  const visit = await repo.findVisitById(visitId);
  if (!visit) {
    throw new Error('Kunjungan tidak ditemukan');
  }
  return visit;
}

async function logVisit(visitData, userId) {
  if (!visitData.cafe_id) {
    throw new Error('Cafe wajib dipilih');
  }

  const visit = await repo.createVisit({
    ...visitData,
    user_id: userId
  });

  return visit;
}

async function editVisit(visitId, userId, visitData) {
  const isOwner = await repo.isVisitOwner(visitId, userId);
  if (!isOwner) {
    throw new Error('Anda tidak memiliki akses ke kunjungan ini');
  }

  const updated = await repo.updateVisit(visitId, visitData);
  if (!updated) {
    throw new Error('Kunjungan tidak ditemukan');
  }

  return updated;
}

async function removeVisit(visitId, userId) {
  const isOwner = await repo.isVisitOwner(visitId, userId);
  if (!isOwner) {
    throw new Error('Anda tidak memiliki akses ke kunjungan ini');
  }

  const deleted = await repo.deleteVisit(visitId);
  if (!deleted) {
    throw new Error('Kunjungan tidak ditemukan');
  }

  return deleted;
}

module.exports = {
  getUserDiary,
  getVisitDetail,
  logVisit,
  editVisit,
  removeVisit
};