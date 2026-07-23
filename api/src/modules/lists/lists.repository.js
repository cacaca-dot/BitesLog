const pool = require('../../config/db');

async function findMyLists(userId) {
  const query = `
    SELECT l.id, l.title, l.description, l.is_public, l.user_id, l.created_at, l.updated_at,
           COUNT(li.id)::int AS cafe_count,
           (SELECT COUNT(*)::int FROM likes WHERE target_type='list' AND target_id=l.id) AS like_count
    FROM lists l
    LEFT JOIN list_items li ON l.id = li.list_id
    WHERE l.user_id = $1
    GROUP BY l.id
    ORDER BY l.created_at DESC
  `;
  const result = await pool.query(query, [userId]);
  return result.rows.map(row => ({
    ...row,
    covers: []
  }));
}

async function findSavedLists(userId) {
  const query = `
    SELECT l.id, l.title, l.description, l.is_public, l.user_id, l.created_at, l.updated_at,
           COUNT(li.id)::int AS cafe_count,
           (SELECT COUNT(*)::int FROM likes WHERE target_type='list' AND target_id=l.id) AS like_count
    FROM lists l
    JOIN saved_lists sl ON sl.list_id = l.id
    LEFT JOIN list_items li ON l.id = li.list_id
    WHERE sl.user_id = $1
    GROUP BY l.id, sl.created_at
    ORDER BY sl.created_at DESC
  `;
  const result = await pool.query(query, [userId]);
  return result.rows.map(row => ({
    ...row,
    covers: []
  }));
}

async function findListById(id, requestUserId) {
  const query = `
    SELECT l.id, l.title, l.description, l.is_public, l.user_id, l.created_at, l.updated_at,
           (SELECT COUNT(*)::int FROM list_items li WHERE li.list_id = l.id) AS cafe_count,
           (SELECT COUNT(*)::int FROM likes lk WHERE lk.target_type = 'list' AND lk.target_id = l.id) AS like_count,
           (SELECT COUNT(*)::int FROM comments c WHERE c.target_type = 'list' AND c.target_id = l.id) AS comment_count,
           (SELECT EXISTS(SELECT 1 FROM likes WHERE target_type = 'list' AND target_id = l.id AND user_id = $2)) AS is_liked,
           (SELECT EXISTS(SELECT 1 FROM saved_lists WHERE list_id = l.id AND user_id = $2)) AS is_saved,
           u.id AS author_id, u.username AS author_username, u.full_name AS author_full_name, u.avatar_url AS author_avatar_url
    FROM lists l
    JOIN users u ON l.user_id = u.id
    WHERE l.id = $1
  `;
  const result = await pool.query(query, [id, requestUserId]);
  if (!result.rows[0]) return null;
  
  const raw = result.rows[0];
  const list = {
    id: raw.id,
    title: raw.title,
    description: raw.description,
    is_public: raw.is_public,
    user_id: raw.user_id,
    created_at: raw.created_at,
    updated_at: raw.updated_at,
    cafe_count: raw.cafe_count,
    like_count: raw.like_count,
    comment_count: raw.comment_count,
    is_liked: raw.is_liked,
    is_saved: raw.is_saved,
    author: {
      id: raw.author_id,
      username: raw.author_username,
      full_name: raw.author_full_name,
      avatar_url: raw.author_avatar_url
    },
    covers: []
  };
  return list;
}

async function findListItems(listId) {
  const query = `
    SELECT li.cafe_id, li."position", li.note,
           c.name, c.categories, c.city, c.avg_rating, c.image_url AS "imageUrl"
    FROM list_items li
    JOIN cafes c ON li.cafe_id = c.id
    WHERE li.list_id = $1
    ORDER BY li."position" ASC
  `;
  const result = await pool.query(query, [listId]);
  return result.rows;
}

async function createList(userId, { title, description, is_public }) {
  const query = `
    INSERT INTO lists (user_id, title, description, is_public)
    VALUES ($1, $2, $3, COALESCE($4, true))
    RETURNING id, title, description, is_public, user_id, created_at, updated_at
  `;
  const result = await pool.query(query, [userId, title, description, is_public]);
  const list = result.rows[0];
  list.cafe_count = 0;
  list.covers = [];
  return list;
}

async function updateList(id, { title, description, is_public }) {
  const query = `
    UPDATE lists
    SET title = COALESCE($1, title),
        description = COALESCE($2, description),
        is_public = COALESCE($3, is_public)
    WHERE id = $4
    RETURNING id, title, description, is_public, user_id, created_at, updated_at
  `;
  const result = await pool.query(query, [title, description, is_public, id]);
  return result.rows[0];
}

async function deleteList(id) {
  const query = `DELETE FROM lists WHERE id = $1`;
  await pool.query(query, [id]);
}

async function addCafeToList(listId, cafeId, note) {
  const query = `
    INSERT INTO list_items (list_id, cafe_id, position, note)
    VALUES (
      $1, 
      $2, 
      (SELECT COALESCE(MAX(position), -1) + 1 FROM list_items WHERE list_id = $1), 
      $3
    )
    RETURNING id, list_id, cafe_id, position, note
  `;
  const result = await pool.query(query, [listId, cafeId, note]);
  return result.rows[0];
}

async function removeCafeFromList(listId, cafeId) {
  const query = `DELETE FROM list_items WHERE list_id = $1 AND cafe_id = $2`;
  await pool.query(query, [listId, cafeId]);
}

async function reorderCafeItems(listId, orderArray) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    for (let i = 0; i < orderArray.length; i++) {
      const cafeId = orderArray[i];
      await client.query(
        `UPDATE list_items SET "position" = $1 WHERE list_id = $2 AND cafe_id = $3`,
        [i, listId, cafeId]
      );
    }
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function updateCafeNote(listId, cafeId, note) {
  const query = `
    UPDATE list_items 
    SET note = $1 
    WHERE list_id = $2 AND cafe_id = $3
    RETURNING id, list_id, cafe_id, position, note
  `;
  const result = await pool.query(query, [note, listId, cafeId]);
  return result.rows[0];
}

async function saveList(userId, listId) {
  const query = `
    INSERT INTO saved_lists (user_id, list_id)
    VALUES ($1, $2)
    ON CONFLICT DO NOTHING
  `;
  await pool.query(query, [userId, listId]);
}

async function unsaveList(userId, listId) {
  const query = `
    DELETE FROM saved_lists
    WHERE user_id = $1 AND list_id = $2
  `;
  await pool.query(query, [userId, listId]);
}

module.exports = {
  findMyLists,
  findSavedLists,
  findListById,
  findListItems,
  createList,
  updateList,
  deleteList,
  addCafeToList,
  removeCafeFromList,
  reorderCafeItems,
  updateCafeNote,
  saveList,
  unsaveList
};
