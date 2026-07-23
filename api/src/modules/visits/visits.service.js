const repo = require('./visits.repository');
const { canViewContent } = require('../../utils/privacy.helper');

async function getUserDiary(userId) {
  return await repo.findVisitsByUser(userId);
}

async function getVisitDetail(visitId, userId) {
  const visit = await repo.findVisitById(visitId, userId);
  if (!visit) {
    throw new Error('Kunjungan tidak ditemukan');
  }

  // Privacy check
  const canView = await canViewContent(userId, visit.user_id);
  if (!canView) {
    const error = new Error('Konten privat');
    error.code = 'FORBIDDEN';
    throw error;
  }

  return visit;
}

async function logVisit(visitData, userId) {
  if (!visitData.cafe_id) {
    throw new Error('Cafe wajib dipilih');
  }

  const hasRating = visitData.rating !== undefined && visitData.rating !== null;
  const hasReview = visitData.review !== undefined && visitData.review !== null && visitData.review.trim() !== '';

  if (!hasRating && !hasReview) {
    throw new Error('Isi minimal rating atau review');
  }

  const date = visitData.visit_date || new Date().toISOString().split('T')[0];

  const visit = await repo.createVisit({
    ...visitData,
    visit_date: date,
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