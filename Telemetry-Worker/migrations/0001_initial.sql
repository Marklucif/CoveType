CREATE TABLE IF NOT EXISTS installations (
  install_hash TEXT PRIMARY KEY,
  first_seen TEXT NOT NULL,
  last_seen TEXT NOT NULL,
  country TEXT NOT NULL,
  app_version TEXT NOT NULL,
  macos_version TEXT NOT NULL,
  architecture TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS installations_last_seen_idx
ON installations(last_seen);

CREATE TABLE IF NOT EXISTS daily_activity (
  day TEXT NOT NULL,
  install_hash TEXT NOT NULL,
  country TEXT NOT NULL,
  app_version TEXT NOT NULL,
  macos_version TEXT NOT NULL,
  architecture TEXT NOT NULL,
  PRIMARY KEY (day, install_hash)
);

CREATE INDEX IF NOT EXISTS daily_activity_day_idx
ON daily_activity(day);

CREATE INDEX IF NOT EXISTS daily_activity_day_country_idx
ON daily_activity(day, country);
