require('dotenv').config({ path: 'api/.env' });
const pool = require('./api/src/config/db');

async function testFeed() {
  try {
    const result = await pool.query(
      `WITH followed_visits AS (
         SELECT v.*,
           ROW_NUMBER() OVER (PARTITION BY v.user_id ORDER BY v.created_at DESC) AS user_rank
         FROM visits v
         JOIN follows f ON f.following_id = v.user_id
         WHERE f.follower_id = $1
       ),
       feed_visits AS (
         SELECT * FROM followed_visits WHERE user_rank <= 10
         UNION ALL
         SELECT v.*, 0 AS user_rank FROM visits v WHERE v.user_id = $1
       )
       SELECT 
         fv.id as visit_id,
         fv.visit_date,
         fv.rating,
         fv.review,
         fv.favorite_drink,
         fv.photo_path,
         fv.created_at,
         u.id as user_id,
         u.username,
         u.full_name,
         u.avatar_url,
         c.id as cafe_id,
         c.name as cafe_name,
         c.city as cafe_city,
         (
           SELECT COALESCE(json_agg(json_build_object('url', vp.url, 'position', vp."position") ORDER BY vp."position" ASC), '[]'::json)
           FROM visit_photos vp
           WHERE vp.visit_id = fv.id
         ) as photos,
         (SELECT COUNT(*) FROM likes WHERE target_type = 'review' AND target_id = fv.id) as like_count,
         (SELECT COUNT(*) FROM comments WHERE target_type = 'review' AND target_id = fv.id) as comment_count,
         EXISTS(SELECT 1 FROM likes WHERE target_type = 'review' AND target_id = fv.id AND user_id = $1) as is_liked
       FROM feed_visits fv
       JOIN users u ON u.id = fv.user_id
       JOIN cafes c ON c.id = fv.cafe_id
       ORDER BY fv.created_at DESC
       LIMIT 20`,
      ['b458c306-6927-4a00-99c5-3411b0e00f9f'] // dummy uuid
    );
    console.log("SUCCESS:", result.rows.length);
  } catch (err) {
    console.error("ERROR:", err.message);
  } finally {
    process.exit(0);
  }
}

testFeed();
