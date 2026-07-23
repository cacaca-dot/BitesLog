const pool = require('../../config/db');

async function findCafes({ search, categories, areas, city, min_rating, price_range }) {
  let query = `
    SELECT id, name, area, categories, city, price_range, avg_rating, visit_count, image_url
    FROM cafes
    WHERE 1=1
  `;
  const params = [];
  let paramIndex = 1;

  if (search) {
    query += ` AND name ILIKE $${paramIndex}`;
    params.push(`%${search}%`);
    paramIndex++;
  }

  if (categories) {
    const catArray = Array.isArray(categories) ? categories : categories.split(',').map(c => c.trim());
    query += ` AND categories && $${paramIndex}::text[]`;
    params.push(catArray);
    paramIndex++;
  }

  if (areas) {
    const areaArray = Array.isArray(areas) ? areas : areas.split(',').map(a => a.trim());
    query += ` AND area = ANY($${paramIndex}::text[])`;
    params.push(areaArray);
    paramIndex++;
  }

  if (city) {
    query += ` AND city ILIKE $${paramIndex}`;
    params.push(`%${city}%`);
    paramIndex++;
  }

  if (min_rating) {
    query += ` AND avg_rating >= $${paramIndex}`;
    params.push(min_rating);
    paramIndex++;
  }
  
  if (price_range) {
    const priceArray = price_range.split(',').map(p => p.trim());
    query += ` AND price_range::text = ANY($${paramIndex}::text[])`;
    params.push(priceArray);
    paramIndex++;
  }

  query += ` ORDER BY visit_count DESC, avg_rating DESC NULLS LAST LIMIT 50`;

  const result = await pool.query(query, params);
  return result.rows;
}

async function getFilters() {
  const areasQuery = await pool.query('SELECT DISTINCT area FROM cafes WHERE area IS NOT NULL ORDER BY area ASC');
  const citiesQuery = await pool.query('SELECT DISTINCT city FROM cafes WHERE city IS NOT NULL ORDER BY city ASC');
  
  return {
    categories: ['Kopi', 'Non-Kopi', 'Dessert', 'Roti', 'Kue', 'Makanan Berat', 'Brunch', 'Lainnya'],
    areas: areasQuery.rows.map(r => r.area),
    cities: citiesQuery.rows.map(r => r.city)
  };
}

async function findCafeById(cafeId, userId = null) {
  const result = await pool.query(
    `SELECT id, name, categories, area, address, city, price_range, 
            latitude, longitude, avg_rating, visit_count,
            created_by, created_at, image_url,
            (CASE WHEN $2::uuid IS NOT NULL THEN EXISTS(SELECT 1 FROM watchlist WHERE cafe_id = cafes.id AND user_id = $2) ELSE false END) as is_in_watchlist
     FROM cafes 
     WHERE id = $1`,
    [cafeId, userId]
  );
  return result.rows[0];
}

async function createCafe({ name, categories, area, address, city, price_range, latitude, longitude, image_url, created_by }) {
  const result = await pool.query(
    `INSERT INTO cafes (name, categories, area, address, city, price_range, 
                        latitude, longitude, image_url, created_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING id, name, categories, area, address, city, price_range, 
               latitude, longitude, image_url, avg_rating, visit_count, created_by, created_at`,
    [name, categories, area, address, city, price_range, latitude, longitude, image_url, created_by]
  );
  return result.rows[0];
}

async function findSimilarCafes(name, city, latitude = null, longitude = null) {
  if (!name || !city) return [];
  
  const cleanName = name.replace(/\s+/g, ' ').trim().toLowerCase();
  
  const query = `
    SELECT id, name, city, address, avg_rating,
      (
        CASE 
          WHEN $3::numeric IS NOT NULL AND $4::numeric IS NOT NULL AND latitude IS NOT NULL AND longitude IS NOT NULL THEN
            ROUND((6371000 * acos(LEAST(1.0, cos(radians($3)) * cos(radians(latitude)) * cos(radians(longitude) - radians($4)) + sin(radians($3)) * sin(radians(latitude)))))::numeric, 2)
          ELSE NULL
        END
      ) as distance_m
    FROM cafes
    WHERE 
      (REGEXP_REPLACE(LOWER(name), '\\s+', ' ', 'g') ILIKE '%' || $2 || '%')
      AND (
        city ILIKE $1 
        OR (
          $3::numeric IS NOT NULL AND $4::numeric IS NOT NULL AND latitude IS NOT NULL AND longitude IS NOT NULL AND
          (6371000 * acos(LEAST(1.0, cos(radians($3)) * cos(radians(latitude)) * cos(radians(longitude) - radians($4)) + sin(radians($3)) * sin(radians(latitude))))) <= 150
        )
      )
    ORDER BY distance_m ASC NULLS LAST, name ASC
    LIMIT 5
  `;
  const result = await pool.query(query, [city, cleanName, latitude, longitude]);
  return result.rows;
}

async function findCafeReviews(cafeId, currentUserId) {
  const query = `
    SELECT v.id as visit_id, v.rating, v.review, v.favorite_drink, v.photo_path, v.created_at,
           CASE 
             WHEN u.is_private = true AND u.id != $2 AND NOT EXISTS(SELECT 1 FROM follows WHERE follower_id = $2 AND following_id = u.id) 
             THEN NULL 
             ELSE u.id 
           END as user_id,
           CASE 
             WHEN u.is_private = true AND u.id != $2 AND NOT EXISTS(SELECT 1 FROM follows WHERE follower_id = $2 AND following_id = u.id) 
             THEN 'Pengguna privat' 
             ELSE u.username 
           END as username,
           CASE 
             WHEN u.is_private = true AND u.id != $2 AND NOT EXISTS(SELECT 1 FROM follows WHERE follower_id = $2 AND following_id = u.id) 
             THEN NULL 
             ELSE u.avatar_url 
           END as avatar,
           CASE 
             WHEN u.is_private = true AND u.id != $2 AND NOT EXISTS(SELECT 1 FROM follows WHERE follower_id = $2 AND following_id = u.id) 
             THEN true 
             ELSE false 
           END as is_anonymous,
           (
             SELECT COALESCE(json_agg(json_build_object('url', vp.url, 'position', vp."position") ORDER BY vp."position" ASC), '[]'::json)
             FROM visit_photos vp
             WHERE vp.visit_id = v.id
           ) as photos,
           (SELECT COUNT(*) FROM likes WHERE target_type = 'review' AND target_id = v.id) as like_count,
           (SELECT COUNT(*) FROM comments WHERE target_type = 'review' AND target_id = v.id) as comment_count,
           EXISTS(SELECT 1 FROM likes WHERE target_type = 'review' AND target_id = v.id AND user_id = $2) as is_liked
    FROM visits v
    JOIN users u ON u.id = v.user_id
    WHERE v.cafe_id = $1
    ORDER BY v.created_at DESC
  `;
  const result = await pool.query(query, [cafeId, currentUserId]);
  return result.rows;
}

async function getCafePhotos(cafeId) {
  const result = await pool.query(
    `SELECT vp.url, vp.visit_id, v.user_id, u.username, vp.created_at
     FROM visit_photos vp
     JOIN visits v ON v.id = vp.visit_id
     JOIN users u ON u.id = v.user_id
     WHERE v.cafe_id = $1
     ORDER BY vp.created_at DESC`,
    [cafeId]
  );
  return result.rows;
}

module.exports = {
  findCafes,
  getFilters,
  findCafeById,
  createCafe,
  findSimilarCafes,
  findCafeReviews,
  getCafePhotos
};