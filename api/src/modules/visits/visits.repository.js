const pool = require('../../config/db');

async function findVisitsByUser(userId) {
  const result = await pool.query(
    `SELECT v.id, v.visit_date, v.rating, v.review, v.favorite_drink, 
            v.price, v.photo_path, v.notes, v.created_at,
            c.id as cafe_id, c.name as cafe_name, c.city as cafe_city,
            (
              SELECT COALESCE(json_agg(json_build_object('url', vp.url, 'position', vp."position") ORDER BY vp."position" ASC), '[]'::json)
              FROM visit_photos vp
              WHERE vp.visit_id = v.id
            ) as photos
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     WHERE v.user_id = $1
     ORDER BY v.visit_date DESC, v.created_at DESC`,
    [userId]
  );
  return result.rows;
}

async function findVisitById(visitId, currentUserId = null) {
  const result = await pool.query(
    `SELECT v.*, 
            c.id as cafe_id, c.name as cafe_name, c.city as cafe_city,
            u.username, u.full_name, u.avatar_url,
            (
              SELECT COALESCE(json_agg(json_build_object('url', vp.url, 'position', vp."position") ORDER BY vp."position" ASC), '[]'::json)
              FROM visit_photos vp
              WHERE vp.visit_id = v.id
            ) as photos,
            (SELECT COUNT(*) FROM likes WHERE target_type = 'review' AND target_id = v.id) as like_count,
            (SELECT COUNT(*) FROM comments WHERE target_type = 'review' AND target_id = v.id) as comment_count,
            EXISTS(SELECT 1 FROM likes WHERE target_type = 'review' AND target_id = v.id AND user_id = $2) as is_liked
     FROM visits v
     JOIN cafes c ON c.id = v.cafe_id
     JOIN users u ON u.id = v.user_id
     WHERE v.id = $1`,
    [visitId, currentUserId]
  );
  return result.rows[0];
}

async function createVisit({ user_id, cafe_id, visit_date, rating, review, favorite_drink, price, photos, notes }) {
  const photo_path = (photos && photos.length > 0) ? photos[0] : null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    const result = await client.query(
      `INSERT INTO visits (user_id, cafe_id, visit_date, rating, review, favorite_drink, price, photo_path, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [user_id, cafe_id, visit_date, rating, review, favorite_drink, price, photo_path, notes]
    );
    const visit = result.rows[0];

    if (photos && photos.length > 0) {
      for (let i = 0; i < photos.length; i++) {
        await client.query(
          `INSERT INTO visit_photos (visit_id, url, "position") VALUES ($1, $2, $3)`,
          [visit.id, photos[i], i]
        );
      }
    }

    await client.query('COMMIT');
    
    const photosResult = await client.query(
      `SELECT url, "position" FROM visit_photos WHERE visit_id = $1 ORDER BY "position" ASC`,
      [visit.id]
    );
    visit.photos = photosResult.rows;
    
    return visit;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function updateVisit(visitId, { visit_date, rating, review, favorite_drink, price, photos, notes }) {
  const photo_path = (photos && photos.length > 0) ? photos[0] : null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const result = await client.query(
      `UPDATE visits 
       SET visit_date = COALESCE($2, visit_date),
           rating = $3,
           review = $4,
           favorite_drink = $5,
           price = $6,
           photo_path = COALESCE($7, photo_path),
           notes = $8
       WHERE id = $1
       RETURNING *`,
      [visitId, visit_date, rating, review, favorite_drink, price, photo_path, notes]
    );
    const visit = result.rows[0];

    if (!visit) {
        throw new Error('Visit not found');
    }

    if (photos !== undefined) {
      await client.query(`DELETE FROM visit_photos WHERE visit_id = $1`, [visitId]);
      if (photos && photos.length > 0) {
        for (let i = 0; i < photos.length; i++) {
          await client.query(
            `INSERT INTO visit_photos (visit_id, url, "position") VALUES ($1, $2, $3)`,
            [visit.id, photos[i], i]
          );
        }
      }
    }

    await client.query('COMMIT');

    const photosResult = await client.query(
      `SELECT url, "position" FROM visit_photos WHERE visit_id = $1 ORDER BY "position" ASC`,
      [visit.id]
    );
    visit.photos = photosResult.rows;

    return visit;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function deleteVisit(visitId) {
  const result = await pool.query(
    `DELETE FROM visits WHERE id = $1 RETURNING id`,
    [visitId]
  );
  return result.rows[0];
}

async function isVisitOwner(visitId, userId) {
  const result = await pool.query(
    `SELECT id FROM visits WHERE id = $1 AND user_id = $2`,
    [visitId, userId]
  );
  return result.rows.length > 0;
}

module.exports = {
  findVisitsByUser,
  findVisitById,
  createVisit,
  updateVisit,
  deleteVisit,
  isVisitOwner
};