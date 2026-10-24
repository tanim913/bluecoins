-- Profile: a display name and an optional gender live on the existing settings row, so they sync
-- and restore with everything else. The profile photo is never uploaded (it stays on the phone).
alter table public.settings
  add column display_name text check (char_length(display_name) between 1 and 60),
  add column gender text check (gender in ('male', 'female', 'other', 'private'));
