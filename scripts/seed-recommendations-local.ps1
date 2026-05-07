$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$infraDir = Join-Path $repoRoot "infra"

Push-Location $infraDir

try {
  docker compose exec -T auth-service alembic upgrade head | Out-Host
  docker compose exec -T places-service alembic upgrade head | Out-Host
  docker compose exec -T interactions-service alembic upgrade head | Out-Host
  docker compose exec -T trips-service alembic upgrade head | Out-Host

  $authSeed = @'
from app.db.session import SessionLocal
from app.models.user import User
from app.core.security import hash_password

USERS = [
    {"email": "reco.tester@example.com", "phone": "+79000000001", "password": "Test1234!", "role": "traveler", "is_premium": True},
    {"email": "family.tester@example.com", "phone": "+79000000002", "password": "Test1234!", "role": "traveler", "is_premium": False},
    {"email": "admin.seed@example.com", "phone": "+79000000003", "password": "Admin1234!", "role": "admin", "is_premium": False},
]

db = SessionLocal()
try:
    for payload in USERS:
        user = db.query(User).filter(User.email == payload["email"]).first()
        if user is None:
            user = User(
                email=payload["email"],
                phone=payload["phone"],
                password_hash=hash_password(payload["password"]),
                role=payload["role"],
                is_premium=payload["is_premium"],
                is_2fa_enabled=False,
                totp_enabled=False,
                passkey_enabled=False,
                totp_secret=None,
            )
            db.add(user)
        else:
            user.phone = payload["phone"]
            user.password_hash = hash_password(payload["password"])
            user.role = payload["role"]
            user.is_premium = payload["is_premium"]
            user.is_2fa_enabled = False
            user.totp_enabled = False
            user.passkey_enabled = False
            user.totp_secret = None
    db.commit()
finally:
    db.close()
'@
  $authSeed | docker compose exec -T auth-service python -

  $recoUserId = (docker compose exec -T auth-db psql -U auth -d auth -t -A -c "select id from users where email='reco.tester@example.com';").Trim()
  $familyUserId = (docker compose exec -T auth-db psql -U auth -d auth -t -A -c "select id from users where email='family.tester@example.com';").Trim()

  if ([string]::IsNullOrWhiteSpace($recoUserId) -or [string]::IsNullOrWhiteSpace($familyUserId)) {
    throw "Failed to resolve seeded user ids."
  }

  $authSql = @"
DELETE FROM user_preferences
WHERE user_id IN (
  SELECT id FROM users WHERE email IN ('reco.tester@example.com', 'family.tester@example.com')
);

INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest', 'culture' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest', 'history' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest', 'food' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'trip_format', 'weekend' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'trip_format', 'city' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest_weight:culture', '5' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest_weight:history', '4' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest_weight:food', '3' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest_weight:walk', '3' FROM users WHERE email = 'reco.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'survey_profile_meta', '{"budget":"middle","travel_mode":"walk","pace":"medium","skipped":false}'
FROM users WHERE email = 'reco.tester@example.com';

INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest', 'nature' FROM users WHERE email = 'family.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest', 'family' FROM users WHERE email = 'family.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest', 'museum' FROM users WHERE email = 'family.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'trip_format', 'family' FROM users WHERE email = 'family.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'trip_format', 'roadtrip' FROM users WHERE email = 'family.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest_weight:nature', '5' FROM users WHERE email = 'family.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest_weight:family', '5' FROM users WHERE email = 'family.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'interest_weight:museum', '3' FROM users WHERE email = 'family.tester@example.com';
INSERT INTO user_preferences (user_id, key, value)
SELECT id, 'survey_profile_meta', '{"budget":"comfort","travel_mode":"car","pace":"slow","skipped":false}'
FROM users WHERE email = 'family.tester@example.com';
"@
  $authSql | docker compose exec -T auth-db psql -U auth -d auth

  $placesSql = @"
DELETE FROM place_tags WHERE place_id IN (SELECT id FROM places WHERE source = 'synthetic_seed');
DELETE FROM places WHERE source = 'synthetic_seed';

INSERT INTO places (
  id, external_id, source, status, name, description, image_url, country, city, address,
  lat, lon, category, subcategory, price_level, avg_visit_duration_min, rating, reviews_count
) VALUES
  ('11111111-1111-1111-1111-111111111111', 'seed-msk-1', 'synthetic_seed', 'approved', 'Tretyakov Gallery', 'Classic art museum in central Moscow.', '', 'Россия', 'Москва', 'Лаврушинский переулок, 10', 55.7414, 37.6208, 'place', 'museum', 'middle', 150, 4.9, 2140),
  ('11111111-1111-1111-1111-111111111112', 'seed-msk-2', 'synthetic_seed', 'approved', 'Zaryadye Park', 'Modern urban park with river views.', '', 'Россия', 'Москва', 'улица Варварка, 6', 55.7510, 37.6280, 'place', 'park', 'economy', 90, 4.8, 1800),
  ('11111111-1111-1111-1111-111111111113', 'seed-msk-3', 'synthetic_seed', 'approved', 'White Rabbit Dinner', 'Panoramic restaurant for evening dinner.', '', 'Россия', 'Москва', 'Смоленская площадь, 3', 55.7487, 37.5827, 'food', 'restaurant', 'premium', 120, 4.7, 950),
  ('11111111-1111-1111-1111-111111111114', 'seed-msk-4', 'synthetic_seed', 'approved', 'Arbat Walking Route', 'Pedestrian historic route with cafes and architecture.', '', 'Россия', 'Москва', 'улица Арбат', 55.7522, 37.5925, 'activity', 'walk', 'economy', 80, 4.6, 1200),
  ('11111111-1111-1111-1111-111111111115', 'seed-msk-5', 'synthetic_seed', 'approved', 'Soviet Arcade Museum', 'Interactive retro museum with playable machines.', '', 'Россия', 'Москва', 'улица Рождественка, 12', 55.7607, 37.6248, 'place', 'museum', 'middle', 75, 4.5, 630),
  ('11111111-1111-1111-1111-111111111116', 'seed-msk-6', 'synthetic_seed', 'approved', 'Business Center Food Hall', 'Crowded mall food hall with weak travel relevance.', '', 'Россия', 'Москва', 'Пресненская набережная, 2', 55.7481, 37.5396, 'food', 'fastfood', 'middle', 50, 3.8, 120),
  ('22222222-2222-2222-2222-222222222221', 'seed-spb-1', 'synthetic_seed', 'approved', 'Hermitage Highlights', 'Major museum with world art collection.', '', 'Россия', 'Санкт-Петербург', 'Дворцовая площадь, 2', 59.9398, 30.3146, 'place', 'museum', 'middle', 180, 4.9, 3500),
  ('22222222-2222-2222-2222-222222222222', 'seed-spb-2', 'synthetic_seed', 'approved', 'New Holland Island', 'Leisure island with family-friendly public spaces.', '', 'Россия', 'Санкт-Петербург', 'набережная Адмиралтейского канала, 2', 59.9299, 30.2893, 'place', 'park', 'economy', 100, 4.8, 1700),
  ('22222222-2222-2222-2222-222222222223', 'seed-spb-3', 'synthetic_seed', 'approved', 'Canal Boat Ride', 'Scenic family boat ride through the city center.', '', 'Россия', 'Санкт-Петербург', 'набережная реки Мойки, 70', 59.9314, 30.3050, 'activity', 'event', 'comfort', 70, 4.7, 840),
  ('22222222-2222-2222-2222-222222222224', 'seed-spb-4', 'synthetic_seed', 'approved', 'Peterhof Day Trip', 'Historic palace complex with fountains and gardens.', '', 'Россия', 'Санкт-Петербург', 'Разводная улица, 2', 59.8830, 29.9002, 'place', 'attraction', 'comfort', 240, 4.9, 2400),
  ('22222222-2222-2222-2222-222222222225', 'seed-spb-5', 'synthetic_seed', 'approved', 'Family Science Center', 'Hands-on science exhibits for kids and adults.', '', 'Россия', 'Санкт-Петербург', 'Лиговский проспект, 74', 59.9197, 30.3547, 'place', 'museum', 'middle', 120, 4.6, 540),
  ('22222222-2222-2222-2222-222222222226', 'seed-spb-6', 'synthetic_seed', 'approved', 'Forest Eco Trail', 'Calm green route near the outskirts for a slow pace.', '', 'Россия', 'Санкт-Петербург', 'Приморское шоссе, 427', 60.1532, 29.9384, 'activity', 'nature', 'economy', 140, 4.7, 310);

INSERT INTO place_tags (id, place_id, tag, weight) VALUES
  ('aaaaaaa1-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'culture', 5),
  ('aaaaaaa1-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'history', 4),
  ('aaaaaaa1-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'museum', 5),
  ('aaaaaaa1-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111112', 'nature', 3),
  ('aaaaaaa1-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111112', 'walk', 4),
  ('aaaaaaa1-0000-0000-0000-000000000006', '11111111-1111-1111-1111-111111111113', 'food', 5),
  ('aaaaaaa1-0000-0000-0000-000000000007', '11111111-1111-1111-1111-111111111113', 'city', 2),
  ('aaaaaaa1-0000-0000-0000-000000000008', '11111111-1111-1111-1111-111111111114', 'walk', 5),
  ('aaaaaaa1-0000-0000-0000-000000000009', '11111111-1111-1111-1111-111111111114', 'history', 2),
  ('aaaaaaa1-0000-0000-0000-000000000010', '11111111-1111-1111-1111-111111111115', 'museum', 4),
  ('aaaaaaa1-0000-0000-0000-000000000011', '11111111-1111-1111-1111-111111111115', 'culture', 3),
  ('aaaaaaa1-0000-0000-0000-000000000012', '11111111-1111-1111-1111-111111111116', 'food', 1),
  ('aaaaaaa1-0000-0000-0000-000000000013', '22222222-2222-2222-2222-222222222221', 'culture', 5),
  ('aaaaaaa1-0000-0000-0000-000000000014', '22222222-2222-2222-2222-222222222221', 'museum', 5),
  ('aaaaaaa1-0000-0000-0000-000000000015', '22222222-2222-2222-2222-222222222222', 'family', 4),
  ('aaaaaaa1-0000-0000-0000-000000000016', '22222222-2222-2222-2222-222222222222', 'nature', 3),
  ('aaaaaaa1-0000-0000-0000-000000000017', '22222222-2222-2222-2222-222222222223', 'family', 5),
  ('aaaaaaa1-0000-0000-0000-000000000018', '22222222-2222-2222-2222-222222222223', 'event', 3),
  ('aaaaaaa1-0000-0000-0000-000000000019', '22222222-2222-2222-2222-222222222224', 'history', 4),
  ('aaaaaaa1-0000-0000-0000-000000000020', '22222222-2222-2222-2222-222222222224', 'family', 2),
  ('aaaaaaa1-0000-0000-0000-000000000021', '22222222-2222-2222-2222-222222222225', 'family', 5),
  ('aaaaaaa1-0000-0000-0000-000000000022', '22222222-2222-2222-2222-222222222225', 'museum', 2),
  ('aaaaaaa1-0000-0000-0000-000000000023', '22222222-2222-2222-2222-222222222226', 'nature', 5),
  ('aaaaaaa1-0000-0000-0000-000000000024', '22222222-2222-2222-2222-222222222226', 'family', 2),
  ('aaaaaaa1-0000-0000-0000-000000000025', '11111111-1111-1111-1111-111111111114', 'weekend', 2),
  ('aaaaaaa1-0000-0000-0000-000000000026', '11111111-1111-1111-1111-111111111111', 'city', 3),
  ('aaaaaaa1-0000-0000-0000-000000000027', '22222222-2222-2222-2222-222222222223', 'family', 4),
  ('aaaaaaa1-0000-0000-0000-000000000028', '22222222-2222-2222-2222-222222222226', 'roadtrip', 3);
"@
  $placesSql | docker compose exec -T places-db psql -U places -d places

  $storiesSql = @"
DELETE FROM place_stories
WHERE id IN (
  '50000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000002',
  '50000000-0000-0000-0000-000000000003',
  '50000000-0000-0000-0000-000000000004'
);

INSERT INTO place_stories (
  id, title, cover_image_url, image_url, body_text, place_id, sort_order, is_active
) VALUES
  (
    '50000000-0000-0000-0000-000000000001',
    'Новая выставка в Третьяковке',
    'https://images.unsplash.com/photo-1501612780327-45045538702b?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1501612780327-45045538702b?auto=format&fit=crop&w=1400&q=80',
    'Большая экспозиция русского искусства в центре Москвы. История подходит для продвижения знакового музейного места и сохранения его в избранное прямо из просмотра.',
    '11111111-1111-1111-1111-111111111111',
    10,
    true
  ),
  (
    '50000000-0000-0000-0000-000000000002',
    'Закат в Зарядье',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=1400&q=80',
    'Вечерняя прогулка по парку с видом на реку и центр города. Хорошая история для блока общих рекомендаций и city discovery.',
    '11111111-1111-1111-1111-111111111112',
    20,
    true
  ),
  (
    '50000000-0000-0000-0000-000000000003',
    'Семейный день в Новой Голландии',
    'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1400&q=80',
    'История для семейной аудитории: открытые пространства, отдых с детьми и удобный формат городской прогулки в Петербурге.',
    '22222222-2222-2222-2222-222222222222',
    30,
    true
  ),
  (
    '50000000-0000-0000-0000-000000000004',
    'Петергоф: идея на целый день',
    'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?auto=format&fit=crop&w=1400&q=80',
    'Промо-история для яркой дневной поездки: дворцы, фонтаны и большой маршрут на полдня или целый день.',
    '22222222-2222-2222-2222-222222222224',
    40,
    true
  );
"@
  $storiesSql | docker compose exec -T places-db psql -U places -d places

  $tripsSql = @"
ALTER TABLE trips ADD COLUMN IF NOT EXISTS destination_city VARCHAR(128);

DELETE FROM stages
WHERE trip_id IN (
  SELECT id FROM trips WHERE title IN ('Synthetic Moscow Weekend', 'Synthetic Family Weekend')
);
DELETE FROM expenses
WHERE trip_id IN (
  SELECT id FROM trips WHERE title IN ('Synthetic Moscow Weekend', 'Synthetic Family Weekend')
);
DELETE FROM trips
WHERE title IN ('Synthetic Moscow Weekend', 'Synthetic Family Weekend');

INSERT INTO trips (title, description, destination_city, start_date, end_date, user_id)
VALUES
  ('Synthetic Moscow Weekend', 'Synthetic route near the center of Moscow.', 'Москва', DATE '2026-05-10', DATE '2026-05-12', $recoUserId),
  ('Synthetic Family Weekend', 'Synthetic family route in Saint Petersburg.', 'Санкт-Петербург', DATE '2026-06-01', DATE '2026-06-03', $familyUserId);

INSERT INTO stages (
  trip_id, position, stage_type, subtype, title, start_location, end_location, address,
  latitude, longitude, duration_minutes, cost_rub, notes
)
VALUES
  ((SELECT id FROM trips WHERE title = 'Synthetic Moscow Weekend' AND user_id = $recoUserId), 1, 'place', 'museum', 'Tretyakov Stop', 'Москва', 'Москва', 'Лаврушинский переулок, 10', 55.7414, 37.6208, 120, 800.00, 'Core culture stop'),
  ((SELECT id FROM trips WHERE title = 'Synthetic Moscow Weekend' AND user_id = $recoUserId), 2, 'food', 'restaurant', 'Dinner Near Arbat', 'Москва', 'Москва', 'улица Арбат', 55.7522, 37.5925, 90, 2200.00, 'Evening dinner'),
  ((SELECT id FROM trips WHERE title = 'Synthetic Family Weekend' AND user_id = $familyUserId), 1, 'place', 'museum', 'Science Center Visit', 'Санкт-Петербург', 'Санкт-Петербург', 'Лиговский проспект, 74', 59.9197, 30.3547, 110, 1500.00, 'Family museum'),
  ((SELECT id FROM trips WHERE title = 'Synthetic Family Weekend' AND user_id = $familyUserId), 2, 'activity', 'nature', 'Eco Trail Walk', 'Санкт-Петербург', 'Санкт-Петербург', 'Приморское шоссе, 427', 60.1532, 29.9384, 150, 0.00, 'Slow pace nature stage');

INSERT INTO expenses (trip_id, description, amount_rub, category)
VALUES
  ((SELECT id FROM trips WHERE title = 'Synthetic Moscow Weekend' AND user_id = $recoUserId), 'Museum tickets', 800.00, 'entertainment'),
  ((SELECT id FROM trips WHERE title = 'Synthetic Moscow Weekend' AND user_id = $recoUserId), 'Dinner booking', 2200.00, 'food'),
  ((SELECT id FROM trips WHERE title = 'Synthetic Family Weekend' AND user_id = $familyUserId), 'Science center tickets', 1500.00, 'entertainment');
"@
  $tripsSql | docker compose exec -T trips-db psql -U trips -d trips

  $interactionsSql = @"
DELETE FROM recommendation_impressions WHERE user_id IN ('$recoUserId', '$familyUserId');
DELETE FROM user_place_interactions WHERE user_id IN ('$recoUserId', '$familyUserId');

INSERT INTO recommendation_impressions (id, user_id, place_id, recommendation_id, position, context, created_at) VALUES
  ('30000000-0000-0000-0000-000000000001', '$recoUserId', '11111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 0, 'recommendation', now() - interval '2 days'),
  ('30000000-0000-0000-0000-000000000002', '$recoUserId', '11111111-1111-1111-1111-111111111113', '11111111-1111-1111-1111-111111111113', 1, 'recommendation', now() - interval '2 days'),
  ('30000000-0000-0000-0000-000000000003', '$familyUserId', '22222222-2222-2222-2222-222222222223', '22222222-2222-2222-2222-222222222223', 0, 'recommendation', now() - interval '1 day');

INSERT INTO user_place_interactions (id, user_id, place_id, action, context, session_id, recommendation_id, weight, metadata_json, created_at) VALUES
  ('40000000-0000-0000-0000-000000000001', '$recoUserId', '11111111-1111-1111-1111-111111111111', 'shown', 'recommendation', 'seed-session-a', '11111111-1111-1111-1111-111111111111', 1.0, '{"seed": true}', now() - interval '2 days'),
  ('40000000-0000-0000-0000-000000000002', '$recoUserId', '11111111-1111-1111-1111-111111111111', 'opened', 'recommendation', 'seed-session-a', '11111111-1111-1111-1111-111111111111', 2.0, '{"seed": true}', now() - interval '2 days'),
  ('40000000-0000-0000-0000-000000000003', '$recoUserId', '11111111-1111-1111-1111-111111111111', 'liked', 'recommendation', 'seed-session-a', '11111111-1111-1111-1111-111111111111', 3.0, '{"seed": true}', now() - interval '1 day'),
  ('40000000-0000-0000-0000-000000000004', '$recoUserId', '11111111-1111-1111-1111-111111111114', 'saved', 'recommendation', 'seed-session-a', '11111111-1111-1111-1111-111111111114', 2.0, '{"seed": true}', now() - interval '20 hours'),
  ('40000000-0000-0000-0000-000000000005', '$recoUserId', '11111111-1111-1111-1111-111111111116', 'disliked', 'recommendation', 'seed-session-a', '11111111-1111-1111-1111-111111111116', -3.0, '{"seed": true}', now() - interval '10 hours'),
  ('40000000-0000-0000-0000-000000000006', '$familyUserId', '22222222-2222-2222-2222-222222222223', 'shown', 'recommendation', 'seed-session-b', '22222222-2222-2222-2222-222222222223', 1.0, '{"seed": true}', now() - interval '1 day'),
  ('40000000-0000-0000-0000-000000000007', '$familyUserId', '22222222-2222-2222-2222-222222222223', 'liked', 'recommendation', 'seed-session-b', '22222222-2222-2222-2222-222222222223', 3.0, '{"seed": true}', now() - interval '20 hours'),
  ('40000000-0000-0000-0000-000000000008', '$familyUserId', '22222222-2222-2222-2222-222222222226', 'saved', 'recommendation', 'seed-session-b', '22222222-2222-2222-2222-222222222226', 2.0, '{"seed": true}', now() - interval '6 hours');
"@
  $interactionsSql | docker compose exec -T interactions-db psql -U interactions -d interactions

  Write-Host "Seed complete."
  Write-Host "Users:"
  docker compose exec -T auth-db psql -U auth -d auth -c "select id, email, role from users where email in ('reco.tester@example.com', 'family.tester@example.com', 'admin.seed@example.com') order by id;"
  Write-Host "Places:"
  docker compose exec -T places-db psql -U places -d places -c "select city, count(*) from places where source='synthetic_seed' group by city order by city;"
  Write-Host "Stories:"
  docker compose exec -T places-db psql -U places -d places -c "select title, place_id, sort_order, is_active from place_stories order by sort_order, title;"
  Write-Host "Trips:"
  docker compose exec -T trips-db psql -U trips -d trips -c "select title, destination_city, user_id from trips where title like 'Synthetic %' order by id;"
  Write-Host "Interactions:"
  docker compose exec -T interactions-db psql -U interactions -d interactions -c "select user_id, action, count(*) from user_place_interactions where user_id in ('$recoUserId', '$familyUserId') group by user_id, action order by user_id, action;"
}
finally {
  Pop-Location
}
