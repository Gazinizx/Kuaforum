alter table public.profiles
  drop constraint if exists profiles_only_designated_main_admin;
alter table public.profiles
  add constraint profiles_only_designated_main_admin
  check (is_admin is not true or lower(coalesce(email,'')) = 'gazitasdemir56@gmail.com');