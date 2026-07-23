const repo = require('./lists.repository');

async function getMyLists(userId) {
  return await repo.findMyLists(userId);
}

async function getSavedLists(userId) {
  return await repo.findSavedLists(userId);
}

async function getListDetail(id, userId) {
  const list = await repo.findListById(id, userId);
  if (!list) {
    throw new Error('LIST_NOT_FOUND');
  }
  if (!list.is_public && list.user_id !== userId) {
    throw new Error('FORBIDDEN');
  }
  
  list.is_owner = list.user_id === userId;
  const items = await repo.findListItems(id);
  list.items = items;
  return list;
}

async function createList(userId, data) {
  if (!data.title || data.title.trim() === '') {
    throw new Error('Title list wajib diisi');
  }
  return await repo.createList(userId, data);
}

async function updateList(id, userId, data) {
  const list = await repo.findListById(id);
  if (!list) {
    throw new Error('NOT_FOUND');
  }
  if (list.user_id !== userId) {
    throw new Error('FORBIDDEN');
  }
  return await repo.updateList(id, data);
}

async function deleteList(id, userId) {
  const list = await repo.findListById(id);
  if (!list) {
    throw new Error('NOT_FOUND');
  }
  if (list.user_id !== userId) {
    throw new Error('FORBIDDEN');
  }
  await repo.deleteList(id);
}

async function addItemToList(id, userId, { cafe_id, note }) {
  const list = await repo.findListById(id);
  if (!list) {
    throw new Error('NOT_FOUND');
  }
  if (list.user_id !== userId) {
    throw new Error('FORBIDDEN');
  }
  if (!cafe_id) {
    throw new Error('cafe_id wajib diisi');
  }
  
  try {
    return await repo.addCafeToList(id, cafe_id, note);
  } catch (err) {
    // 23505 is PostgreSQL unique constraint violation error code
    if (err.code === '23505') {
      throw new Error('DUPLICATE');
    }
    throw err;
  }
}

async function removeItemFromList(id, userId, cafeId) {
  const list = await repo.findListById(id);
  if (!list) {
    throw new Error('NOT_FOUND');
  }
  if (list.user_id !== userId) {
    throw new Error('FORBIDDEN');
  }
  await repo.removeCafeFromList(id, cafeId);
}

async function reorderItems(id, userId, orderArray) {
  const list = await repo.findListById(id, userId);
  if (!list) {
    throw new Error('NOT_FOUND');
  }
  if (list.user_id !== userId) {
    throw new Error('FORBIDDEN');
  }
  
  if (!Array.isArray(orderArray)) {
    throw new Error('Format order tidak valid');
  }
  
  // Optional: Validasi apakah semua cafe_id ada di list ini bisa ditambahkan,
  // tapi repository akan skip yang tidak ada karena kondisi AND cafe_id = $3
  await repo.reorderCafeItems(id, orderArray);
  return await repo.findListItems(id);
}

async function updateItemNote(id, userId, cafeId, note) {
  const list = await repo.findListById(id, userId);
  if (!list) {
    throw new Error('NOT_FOUND');
  }
  if (list.user_id !== userId) {
    throw new Error('FORBIDDEN');
  }
  
  const updatedItem = await repo.updateCafeNote(id, cafeId, note);
  if (!updatedItem) {
    throw new Error('Item tidak ditemukan di list ini');
  }
  return updatedItem;
}

async function saveList(userId, listId) {
  const list = await repo.findListById(listId);
  if (!list) throw new Error('NOT_FOUND');
  if (list.user_id === userId) throw new Error('FORBIDDEN');
  await repo.saveList(userId, listId);
}

async function unsaveList(userId, listId) {
  const list = await repo.findListById(listId);
  if (!list) throw new Error('NOT_FOUND');
  await repo.unsaveList(userId, listId);
}

module.exports = {
  getMyLists,
  getSavedLists,
  getListDetail,
  createList,
  updateList,
  deleteList,
  addItemToList,
  removeItemFromList,
  reorderItems,
  updateItemNote,
  saveList,
  unsaveList
};
