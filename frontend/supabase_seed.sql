-- ============================================================
-- NPD Fuel Monitor — Full Demo Seed Script
-- Run in Supabase SQL Editor. Handles existing data cleanly.
-- ============================================================

-- ── 0. ENSURE HANDLE_NEW_USER TRIGGER EXISTS (must run BEFORE the DO block ──
-- below — inserting into auth.users there fires this trigger immediately,
-- so the fixed version must already be in place).
-- Creates profile row automatically on signup for new users.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, role, is_approved)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NULLIF(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'driver')::user_role,
    false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never let a profile-row hiccup (e.g. a stray unique-constraint collision)
  -- block the auth.users insert — registerDriver()'s own upsert covers it.
  RAISE WARNING 'handle_new_user failed for %: %', NEW.email, SQLERRM;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ── 0a. BUDGET TRACKING COLUMN ───────────────────────────────────────────────
-- ADD COLUMN ... DEFAULT backfills existing rows too (Postgres 11+), so
-- driver1-4 (and admin/manager) get 400000 without a separate UPDATE.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS monthly_budget_rwf numeric NOT NULL DEFAULT 400000;

-- ── 0b. SUPER ADMIN ROLE ─────────────────────────────────────────────────────
-- Standalone statement (not inside a DO block) — ALTER TYPE ... ADD VALUE
-- cannot run in the same transaction as code that uses the new value.
-- The Supabase SQL Editor runs this whole script as one implicit transaction,
-- so an explicit COMMIT here is required before 'super_admin' is referenced
-- as an enum literal later in this script (current_user_role() IN (...)).
ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'super_admin';
COMMIT;

-- ── 0c. NOTIFICATIONS TABLE ──────────────────────────────────────────────────
-- Centralized in-app notification center (fuel requests, AI alerts, vehicle
-- assignments, budget thresholds). Created here so Section 0's wipe below can
-- safely DELETE FROM it on every reseed.
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL,
  category text NOT NULL CHECK (category IN ('fuel_request', 'ai_alert', 'vehicle', 'budget')),
  priority text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  related_id uuid,
  dedupe_key text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, dedupe_key)
);
CREATE INDEX IF NOT EXISTS notifications_user_created_idx
  ON public.notifications (user_id, created_at DESC);

DO $$
DECLARE
  v_admin uuid := 'a1111111-0000-0000-0000-000000000001'::uuid;
  v_mgr   uuid := 'a1111111-0000-0000-0000-000000000002'::uuid;
  v_d1    uuid := 'a1111111-0000-0000-0000-000000000011'::uuid;
  v_d2    uuid := 'a1111111-0000-0000-0000-000000000012'::uuid;
  v_d3    uuid := 'a1111111-0000-0000-0000-000000000013'::uuid;
  v_d4    uuid := 'a1111111-0000-0000-0000-000000000014'::uuid;
  v_v1    uuid := 'b1111111-0000-0000-0000-000000000001'::uuid;
  v_v2    uuid := 'b1111111-0000-0000-0000-000000000002'::uuid;
  v_v3    uuid := 'b1111111-0000-0000-0000-000000000003'::uuid;
  v_v4    uuid := 'b1111111-0000-0000-0000-000000000004'::uuid;
BEGIN

-- ── 0. WIPE EXISTING SEED DATA ───────────────────────────────────────────────
-- Delete in FK dependency order: children before parents.
-- fuel_transactions/alerts/trips/requests all FK → profiles, so delete them first.

DELETE FROM public.notifications;
DELETE FROM public.fuel_requests;
DELETE FROM public.alerts;
DELETE FROM public.fuel_transactions;
DELETE FROM public.trip_waypoints;
DELETE FROM public.gps_trips;
UPDATE public.vehicles SET assigned_driver_id = NULL;
DELETE FROM public.vehicles;
DELETE FROM public.fuel_prices;

-- Clean auth records for demo emails (whatever UUID they had from test signups)
-- Pattern-based so it also covers the driver5..driver30 test accounts below.
DELETE FROM auth.identities
  WHERE provider_id IN ('admin@npd.rw','manager@npd.rw')
     OR provider_id LIKE 'driver%@npd.rw';
DELETE FROM auth.users
  WHERE email IN ('admin@npd.rw','manager@npd.rw')
     OR email LIKE 'driver%@npd.rw';
-- Explicit profile cleanup (handles both cascade and non-cascade FK setups)
DELETE FROM public.profiles
  WHERE id::text LIKE 'a1111111-0000-0000-0000-%';

-- ── 1. AUTH USERS ────────────────────────────────────────────────────────────

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token,
  email_change, email_change_token_new, recovery_token
) VALUES
  ('00000000-0000-0000-0000-000000000000', v_admin, 'authenticated', 'authenticated',
   'admin@npd.rw', crypt('npd2024admin', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Celestin Hakizimana","role":"admin"}'::jsonb,
   now(), now(), '', '', '', ''),

  ('00000000-0000-0000-0000-000000000000', v_mgr, 'authenticated', 'authenticated',
   'manager@npd.rw', crypt('npd2024mgr', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Eric Mugisha","role":"fleet_manager"}'::jsonb,
   now(), now(), '', '', '', ''),

  ('00000000-0000-0000-0000-000000000000', v_d1, 'authenticated', 'authenticated',
   'driver1@npd.rw', crypt('npd2024drv', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Jean Baptiste Niyonzima","role":"driver"}'::jsonb,
   now(), now(), '', '', '', ''),

  ('00000000-0000-0000-0000-000000000000', v_d2, 'authenticated', 'authenticated',
   'driver2@npd.rw', crypt('npd2024drv', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Marie Claire Uwimana","role":"driver"}'::jsonb,
   now(), now(), '', '', '', ''),

  ('00000000-0000-0000-0000-000000000000', v_d3, 'authenticated', 'authenticated',
   'driver3@npd.rw', crypt('npd2024drv', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Patrick Habimana","role":"driver"}'::jsonb,
   now(), now(), '', '', '', ''),

  ('00000000-0000-0000-0000-000000000000', v_d4, 'authenticated', 'authenticated',
   'driver4@npd.rw', crypt('npd2024drv', gen_salt('bf')), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Emmanuel Rugamba","role":"driver"}'::jsonb,
   now(), now(), '', '', '', '');

-- Auth identities (email provider)
INSERT INTO auth.identities (
  id, provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
) VALUES
  (v_admin, 'admin@npd.rw',   v_admin, jsonb_build_object('sub', v_admin::text, 'email', 'admin@npd.rw'),   'email', now(), now(), now()),
  (v_mgr,   'manager@npd.rw', v_mgr,   jsonb_build_object('sub', v_mgr::text,   'email', 'manager@npd.rw'), 'email', now(), now(), now()),
  (v_d1,    'driver1@npd.rw', v_d1,    jsonb_build_object('sub', v_d1::text,    'email', 'driver1@npd.rw'), 'email', now(), now(), now()),
  (v_d2,    'driver2@npd.rw', v_d2,    jsonb_build_object('sub', v_d2::text,    'email', 'driver2@npd.rw'), 'email', now(), now(), now()),
  (v_d3,    'driver3@npd.rw', v_d3,    jsonb_build_object('sub', v_d3::text,    'email', 'driver3@npd.rw'), 'email', now(), now(), now()),
  (v_d4,    'driver4@npd.rw', v_d4,    jsonb_build_object('sub', v_d4::text,    'email', 'driver4@npd.rw'), 'email', now(), now(), now());

-- ── 2. PROFILES ──────────────────────────────────────────────────────────────

INSERT INTO public.profiles (id, full_name, phone, role, is_approved) VALUES
  (v_admin, 'Celestin Hakizimana',     '+250788000001', 'admin',         true),
  (v_mgr,   'Eric Mugisha',            '+250788000002', 'fleet_manager', true),
  (v_d1,    'Jean Baptiste Niyonzima', '+250788111001', 'driver',        true),
  (v_d2,    'Marie Claire Uwimana',    '+250788111002', 'driver',        true),
  (v_d3,    'Patrick Habimana',        '+250788111003', 'driver',        true),
  (v_d4,    'Emmanuel Rugamba',        '+250788111004', 'driver',        true)
ON CONFLICT (id) DO UPDATE SET
  full_name   = EXCLUDED.full_name,
  phone       = EXCLUDED.phone,
  role        = EXCLUDED.role,
  is_approved = EXCLUDED.is_approved;

-- ── 2b. EXTRA TEST DRIVER ACCOUNTS — driver5..driver30@npd.rw ────────────────
-- All share password 'npd2024drv'. No vehicle assigned — useful for testing
-- signup/approval, role-based dashboards, and fuel-request flows from many
-- different driver logins without needing 30 separate vehicles/trip sets.
DECLARE
  d_names CONSTANT text[] := ARRAY[
    'Alice Uwase','Eric Niyonsenga','Diane Mukamana','Robert Bizimana','Claudine Ingabire',
    'Jean Paul Habyarimana','Solange Umutoni','Vincent Twagirayezu','Beatrice Nyirahabimana','David Ntwari',
    'Grace Mutesi','Felix Rukundo','Yvonne Uwamahoro','Aimable Nshimiyimana','Christine Mukandayisenga',
    'Olivier Hagenimana','Esperance Nyiraneza','Theogene Mugabo','Jeanne Uwizeyimana','Pacifique Niyibizi',
    'Florence Mukashema','Innocent Ndayisaba','Agnes Uwimbabazi','Damascene Sibomana','Vestine Mukamurenzi',
    'Emmanuel Hategekimana'
  ];
  i      int;
  d_id   uuid;
  d_email text;
BEGIN
  FOR i IN 1..array_length(d_names, 1) LOOP
    d_id    := ('a1111111-0000-0000-0000-' || LPAD((i + 14)::text, 12, '0'))::uuid;
    d_email := 'driver' || (i + 4)::text || '@npd.rw';

    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token,
      email_change, email_change_token_new, recovery_token
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', d_id, 'authenticated', 'authenticated',
      d_email, crypt('npd2024drv', gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', d_names[i], 'role', 'driver'),
      now(), now(), '', '', '', ''
    );

    INSERT INTO auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) VALUES (
      d_id, d_email, d_id,
      jsonb_build_object('sub', d_id::text, 'email', d_email),
      'email', now(), now(), now()
    );

    INSERT INTO public.profiles (id, full_name, phone, role, is_approved)
    VALUES (d_id, d_names[i], '+25078882' || LPAD((1000 + i)::text, 4, '0'), 'driver', true)
    ON CONFLICT (id) DO UPDATE SET
      full_name   = EXCLUDED.full_name,
      phone       = EXCLUDED.phone,
      role        = EXCLUDED.role,
      is_approved = EXCLUDED.is_approved;
  END LOOP;
END;

-- ── 3. VEHICLES ──────────────────────────────────────────────────────────────

INSERT INTO public.vehicles (
  id, plate_number, make, model, year, vehicle_type, fuel_type,
  tank_capacity_l, current_fuel_l, odometer_km, status,
  assigned_driver_id, color
) VALUES
  (v_v1, 'RAE 001 A', 'Toyota', 'Land Cruiser', 2022, 'suv',    'petrol', 90, 52, 24350, 'active', v_d1, 'White'),
  (v_v2, 'RAE 002 B', 'Toyota', 'Hilux',        2021, 'pickup', 'diesel', 80, 14, 31200, 'active', v_d2, 'Silver'),
  (v_v3, 'RAE 003 C', 'Isuzu',  'D-Max',        2023, 'pickup', 'diesel', 75, 61, 18900, 'active', v_d3, 'Black'),
  (v_v4, 'RAE 004 D', 'Toyota', 'Land Cruiser V8', 2024, 'suv', 'petrol', 138, 90, 16200, 'active', v_d4, 'Black')
ON CONFLICT (id) DO UPDATE SET
  current_fuel_l     = EXCLUDED.current_fuel_l,
  odometer_km        = EXCLUDED.odometer_km,
  assigned_driver_id = EXCLUDED.assigned_driver_id;

-- ── 4. FUEL PRICES ───────────────────────────────────────────────────────────

INSERT INTO public.fuel_prices (fuel_type, price_rwf, effective_date, set_by, created_at) VALUES
  ('petrol', 1520.00, '2026-06-01', v_mgr, now()),
  ('diesel', 1450.00, '2026-06-01', v_mgr, now())
ON CONFLICT DO NOTHING;

-- ── 5. GPS TRIPS — Jan–Jun 2026, 4 driver scenarios, working days only ───────
-- Each scenario runs its full multi-stop daily route on every Mon-Fri working
-- day (Jan-May full months, June 1 through today only). A per-driver "mult"
-- sets the consumption profile so the AI engine sees Normal / Efficient /
-- High-Consumption usage across the whole history.

-- Scenario 1: John (Jean Baptiste) — Land Cruiser — home/school/work/lunch loop
DECLARE
  s_eff  CONSTANT numeric  := 8.0;
  s_from CONSTANT text[]   := ARRAY['Busanza','Kibagabaga','NPD Kicukiro','Kimihurura','NPD Kicukiro'];
  s_to   CONSTANT text[]   := ARRAY['Kibagabaga','NPD Kicukiro','Kimihurura','NPD Kicukiro','Busanza'];
  s_olat CONSTANT numeric[] := ARRAY[-1.9897,-1.9217,-1.9706,-1.9499,-1.9706];
  s_olng CONSTANT numeric[] := ARRAY[30.1300,30.1127,30.1044,30.0926,30.1044];
  s_dlat CONSTANT numeric[] := ARRAY[-1.9217,-1.9706,-1.9499,-1.9706,-1.9897];
  s_dlng CONSTANT numeric[] := ARRAY[30.1127,30.1044,30.0926,30.1044,30.1300];
  s_dist CONSTANT numeric[] := ARRAY[12.0,10.0,6.0,6.0,13.0];
  s_min  CONSTANT int[]     := ARRAY[390,435,750,840,1050];
  s_legs CONSTANT int := 5;
  s_seed CONSTANT int := 1;
  mult   CONSTANT numeric := 1.0; -- Normal Usage
  m int; leg int; factor numeric; fuel numeric; dur int;
  st timestamptz; en timestamptz; month_start date; month_end date; d date;
BEGIN
  FOR m IN 0..5 LOOP
    month_start := (date '2026-01-01' + (m::text || ' months')::interval)::date;
    month_end := LEAST((month_start + interval '1 month' - interval '1 day')::date, CURRENT_DATE);
    d := month_start;
    WHILE d <= month_end LOOP
      IF EXTRACT(ISODOW FROM d) <= 5 THEN
        FOR leg IN 1..s_legs LOOP
          factor := mult * (0.90 + ((EXTRACT(DOY FROM d)::int * 7 + leg * 3 + s_seed) % 11) * 0.02);
          fuel := round((s_dist[leg] / s_eff) * factor, 2);
          dur  := GREATEST(round(s_dist[leg] / 40.0 * 60)::int, 5);
          st   := (d::text || ' ' || lpad((s_min[leg] / 60)::text, 2, '0') || ':' || lpad((s_min[leg] % 60)::text, 2, '0') || ':00+02')::timestamptz;
          en   := st + (dur::text || ' minutes')::interval;
          INSERT INTO public.gps_trips (
            id, vehicle_id, driver_id, status, origin_name, destination_name,
            origin_lat, origin_lng, destination_lat, destination_lng,
            distance_km, fuel_consumed_l, fuel_efficiency,
            started_at, ended_at, duration_minutes
          ) VALUES (
            gen_random_uuid(), v_v1, v_d1, 'completed', s_from[leg], s_to[leg],
            s_olat[leg], s_olng[leg], s_dlat[leg], s_dlng[leg],
            s_dist[leg], fuel, s_eff, st, en, dur
          );
        END LOOP;
      END IF;
      d := d + 1;
    END LOOP;
  END LOOP;
END;

-- Scenario 2: Alice (Marie Claire) — Hilux — field-operations loop
DECLARE
  s_eff  CONSTANT numeric  := 9.0;
  s_from CONSTANT text[]   := ARRAY['Busanza','Kanombe','Remera','Kigali Heights','Kimironko','Nyarutarama'];
  s_to   CONSTANT text[]   := ARRAY['Kanombe','Remera','Kigali Heights','Kimironko','Nyarutarama','Busanza'];
  s_olat CONSTANT numeric[] := ARRAY[-1.9897,-1.9706,-1.9577,-1.9527,-1.9417,-1.9379];
  s_olng CONSTANT numeric[] := ARRAY[30.1300,30.1494,30.1127,30.0926,30.1147,30.1027];
  s_dlat CONSTANT numeric[] := ARRAY[-1.9706,-1.9577,-1.9527,-1.9417,-1.9379,-1.9897];
  s_dlng CONSTANT numeric[] := ARRAY[30.1494,30.1127,30.0926,30.1147,30.1027,30.1300];
  s_dist CONSTANT numeric[] := ARRAY[5.0,5.5,4.0,4.5,3.0,13.5];
  s_min  CONSTANT int[]     := ARRAY[420,510,600,720,870,990];
  s_legs CONSTANT int := 6;
  s_seed CONSTANT int := 2;
  mult   CONSTANT numeric := 0.92; -- Efficient Usage
  m int; leg int; factor numeric; fuel numeric; dur int;
  st timestamptz; en timestamptz; month_start date; month_end date; d date;
BEGIN
  FOR m IN 0..5 LOOP
    month_start := (date '2026-01-01' + (m::text || ' months')::interval)::date;
    month_end := LEAST((month_start + interval '1 month' - interval '1 day')::date, CURRENT_DATE);
    d := month_start;
    WHILE d <= month_end LOOP
      IF EXTRACT(ISODOW FROM d) <= 5 THEN
        FOR leg IN 1..s_legs LOOP
          factor := mult * (0.90 + ((EXTRACT(DOY FROM d)::int * 7 + leg * 3 + s_seed) % 11) * 0.02);
          fuel := round((s_dist[leg] / s_eff) * factor, 2);
          dur  := GREATEST(round(s_dist[leg] / 40.0 * 60)::int, 5);
          st   := (d::text || ' ' || lpad((s_min[leg] / 60)::text, 2, '0') || ':' || lpad((s_min[leg] % 60)::text, 2, '0') || ':00+02')::timestamptz;
          en   := st + (dur::text || ' minutes')::interval;
          INSERT INTO public.gps_trips (
            id, vehicle_id, driver_id, status, origin_name, destination_name,
            origin_lat, origin_lng, destination_lat, destination_lng,
            distance_km, fuel_consumed_l, fuel_efficiency,
            started_at, ended_at, duration_minutes
          ) VALUES (
            gen_random_uuid(), v_v2, v_d2, 'completed', s_from[leg], s_to[leg],
            s_olat[leg], s_olng[leg], s_dlat[leg], s_dlng[leg],
            s_dist[leg], fuel, s_eff, st, en, dur
          );
        END LOOP;
      END IF;
      d := d + 1;
    END LOOP;
  END LOOP;
END;

-- Scenario 3: Patrick (Patrick Habimana) — D-Max — sales-rep city loop
DECLARE
  s_eff  CONSTANT numeric  := 9.5;
  s_from CONSTANT text[]   := ARRAY['Kicukiro','Nyamirambo','Downtown Kigali','Gikondo','Kimisagara'];
  s_to   CONSTANT text[]   := ARRAY['Nyamirambo','Downtown Kigali','Gikondo','Kimisagara','Kicukiro'];
  s_olat CONSTANT numeric[] := ARRAY[-1.9706,-1.9783,-1.9499,-1.9783,-1.9550];
  s_olng CONSTANT numeric[] := ARRAY[30.1044,30.0386,30.0588,30.0719,30.0441];
  s_dlat CONSTANT numeric[] := ARRAY[-1.9783,-1.9499,-1.9783,-1.9550,-1.9706];
  s_dlng CONSTANT numeric[] := ARRAY[30.0386,30.0588,30.0719,30.0441,30.1044];
  s_dist CONSTANT numeric[] := ARRAY[7.5,3.5,4.0,4.0,7.0];
  s_min  CONSTANT int[]     := ARRAY[480,570,690,810,930];
  s_legs CONSTANT int := 5;
  s_seed CONSTANT int := 3;
  mult   CONSTANT numeric := 1.30; -- High Consumption
  m int; leg int; factor numeric; fuel numeric; dur int;
  st timestamptz; en timestamptz; month_start date; month_end date; d date;
BEGIN
  FOR m IN 0..5 LOOP
    month_start := (date '2026-01-01' + (m::text || ' months')::interval)::date;
    month_end := LEAST((month_start + interval '1 month' - interval '1 day')::date, CURRENT_DATE);
    d := month_start;
    WHILE d <= month_end LOOP
      IF EXTRACT(ISODOW FROM d) <= 5 THEN
        FOR leg IN 1..s_legs LOOP
          factor := mult * (0.90 + ((EXTRACT(DOY FROM d)::int * 7 + leg * 3 + s_seed) % 11) * 0.02);
          fuel := round((s_dist[leg] / s_eff) * factor, 2);
          dur  := GREATEST(round(s_dist[leg] / 40.0 * 60)::int, 5);
          st   := (d::text || ' ' || lpad((s_min[leg] / 60)::text, 2, '0') || ':' || lpad((s_min[leg] % 60)::text, 2, '0') || ':00+02')::timestamptz;
          en   := st + (dur::text || ' minutes')::interval;
          INSERT INTO public.gps_trips (
            id, vehicle_id, driver_id, status, origin_name, destination_name,
            origin_lat, origin_lng, destination_lat, destination_lng,
            distance_km, fuel_consumed_l, fuel_efficiency,
            started_at, ended_at, duration_minutes
          ) VALUES (
            gen_random_uuid(), v_v3, v_d3, 'completed', s_from[leg], s_to[leg],
            s_olat[leg], s_olng[leg], s_dlat[leg], s_dlng[leg],
            s_dist[leg], fuel, s_eff, st, en, dur
          );
        END LOOP;
      END IF;
      d := d + 1;
    END LOOP;
  END LOOP;
END;

-- Scenario 4: Manager (Emmanuel Rugamba) — Land Cruiser V8 — executive loop
DECLARE
  s_eff  CONSTANT numeric  := 6.0;
  s_from CONSTANT text[]   := ARRAY['Nyarutarama','Kigali Convention Centre','Ministry Offices','Serena Hotel'];
  s_to   CONSTANT text[]   := ARRAY['Kigali Convention Centre','Ministry Offices','Serena Hotel','Nyarutarama'];
  s_olat CONSTANT numeric[] := ARRAY[-1.9379,-1.9536,-1.9441,-1.9477];
  s_olng CONSTANT numeric[] := ARRAY[30.1027,30.0927,30.0619,30.0615];
  s_dlat CONSTANT numeric[] := ARRAY[-1.9536,-1.9441,-1.9477,-1.9379];
  s_dlng CONSTANT numeric[] := ARRAY[30.0927,30.0619,30.0615,30.1027];
  s_dist CONSTANT numeric[] := ARRAY[3.0,4.5,0.6,4.5];
  s_min  CONSTANT int[]     := ARRAY[510,600,780,1020];
  s_legs CONSTANT int := 4;
  s_seed CONSTANT int := 4;
  mult   CONSTANT numeric := 1.00; -- Normal Usage
  m int; leg int; factor numeric; fuel numeric; dur int;
  st timestamptz; en timestamptz; month_start date; month_end date; d date;
BEGIN
  FOR m IN 0..5 LOOP
    month_start := (date '2026-01-01' + (m::text || ' months')::interval)::date;
    month_end := LEAST((month_start + interval '1 month' - interval '1 day')::date, CURRENT_DATE);
    d := month_start;
    WHILE d <= month_end LOOP
      IF EXTRACT(ISODOW FROM d) <= 5 THEN
        FOR leg IN 1..s_legs LOOP
          factor := mult * (0.90 + ((EXTRACT(DOY FROM d)::int * 7 + leg * 3 + s_seed) % 11) * 0.02);
          fuel := round((s_dist[leg] / s_eff) * factor, 2);
          dur  := GREATEST(round(s_dist[leg] / 40.0 * 60)::int, 5);
          st   := (d::text || ' ' || lpad((s_min[leg] / 60)::text, 2, '0') || ':' || lpad((s_min[leg] % 60)::text, 2, '0') || ':00+02')::timestamptz;
          en   := st + (dur::text || ' minutes')::interval;
          INSERT INTO public.gps_trips (
            id, vehicle_id, driver_id, status, origin_name, destination_name,
            origin_lat, origin_lng, destination_lat, destination_lng,
            distance_km, fuel_consumed_l, fuel_efficiency,
            started_at, ended_at, duration_minutes
          ) VALUES (
            gen_random_uuid(), v_v4, v_d4, 'completed', s_from[leg], s_to[leg],
            s_olat[leg], s_olng[leg], s_dlat[leg], s_dlng[leg],
            s_dist[leg], fuel, s_eff, st, en, dur
          );
        END LOOP;
      END IF;
      d := d + 1;
    END LOOP;
  END LOOP;
END;

-- ── 5b. TRIP WAYPOINTS — 21 interpolated GPS fixes per trip (current month only) ──
-- Gives each June 2026 trip a realistic route line + speed/fuel telemetry on the map.
-- Older months keep trip-level stats only (used for charts/AI history, not live map).
DECLARE
  trip_rec RECORD;
  wp_i     int;
  wp_steps CONSTANT int := 20;
  wp_frac  numeric;
BEGIN
  FOR trip_rec IN
    SELECT * FROM public.gps_trips
    WHERE driver_id IN (v_d1, v_d2, v_d3, v_d4)
      AND started_at >= '2026-06-01'::timestamptz
      AND started_at <  '2026-07-01'::timestamptz
  LOOP
    FOR wp_i IN 0..wp_steps LOOP
      wp_frac := wp_i::numeric / wp_steps;
      INSERT INTO public.trip_waypoints (
        id, trip_id, sequence_no, latitude, longitude,
        speed_kmh, fuel_level_l, recorded_at
      ) VALUES (
        gen_random_uuid(),
        trip_rec.id,
        wp_i,
        trip_rec.origin_lat + (trip_rec.destination_lat - trip_rec.origin_lat) * wp_frac,
        trip_rec.origin_lng + (trip_rec.destination_lng - trip_rec.origin_lng) * wp_frac,
        CASE WHEN wp_i = 0 OR wp_i = wp_steps THEN 0 ELSE 70.0 + (wp_i % 4) * 12.0 END,
        50.0 - (trip_rec.fuel_consumed_l / wp_steps) * wp_i,
        trip_rec.started_at + (trip_rec.ended_at - trip_rec.started_at) * wp_frac
      );
    END LOOP;
  END LOOP;
END;

-- ── 6. FUEL TRANSACTIONS — Jan–Jun 2026, 4 weekly refills/vehicle/month ──────

DECLARE
  f_month int;
  f_idx   int;
  f_days  CONSTANT int[] := ARRAY[1, 8, 15, 22];
  f_date  date;
BEGIN
  FOR f_month IN 0..5 LOOP
    FOR f_idx IN 1..4 LOOP
      f_date := (date '2026-01-01' + (f_month::text || ' months')::interval)::date + (f_days[f_idx] - 1);
      CONTINUE WHEN f_date > CURRENT_DATE;

      INSERT INTO public.fuel_transactions (
        id, vehicle_id, driver_id, transaction_type,
        quantity_l, unit_price_rwf, total_cost_rwf,
        odometer_km, recorded_at, notes
      ) VALUES
        (gen_random_uuid(), v_v1, v_d1, 'refill',
         60.0, 1520.0, 91200.0, 18000.0 + (f_month * 4 + (f_idx - 1)) * 280.0,
         (f_date::text || ' 12:00:00+02')::timestamptz,
         'Weekly refill — Busanza/Kicukiro commute route'),

        (gen_random_uuid(), v_v2, v_d2, 'refill',
         80.0, 1450.0, 116000.0, 27290.0 + (f_month * 4 + (f_idx - 1)) * 170.0,
         (f_date::text || ' 11:30:00+02')::timestamptz,
         'Weekly refill — field operations route'),

        (gen_random_uuid(), v_v3, v_d3, 'refill',
         50.0, 1450.0, 72500.0, 16715.0 + (f_month * 4 + (f_idx - 1)) * 95.0,
         (f_date::text || ' 13:00:00+02')::timestamptz,
         'Weekly refill — sales route'),

        (gen_random_uuid(), v_v4, v_d4, 'refill',
         70.0, 1520.0, 106400.0, 13670.0 + (f_month * 4 + (f_idx - 1)) * 110.0,
         (f_date::text || ' 09:00:00+02')::timestamptz,
         'Weekly refill — executive transport');
    END LOOP;
  END LOOP;
END;

-- ── 7. ALERTS ────────────────────────────────────────────────────────────────

INSERT INTO public.alerts (
  id, vehicle_id, driver_id, alert_type, severity, status, title, description,
  ai_confidence, created_at
) VALUES
  (gen_random_uuid(), v_v2, v_d2, 'low_fuel', 'critical', 'open',
   'Low Fuel Alert',
   'RAE 002 B fuel level at 17.5% (14 L / 80 L). Immediate refill required.',
   0.98, now() - interval '3 hours'),

  (gen_random_uuid(), v_v1, v_d1, 'unusual_route', 'high', 'open',
   'Overspeed Detected',
   'RAE 001 A recorded 143 km/h on Kigali–Musanze highway (limit: 80 km/h).',
   0.95, now() - interval '1 day 6 hours'),

  (gen_random_uuid(), v_v3, v_d3, 'possible_theft', 'medium', 'acknowledged',
   'Possible Fuel Theft',
   'RAE 003 C trip on 18,900 km log shows 45% more fuel consumed than the route''s expected usage.',
   0.88, now() - interval '5 days'),

  (gen_random_uuid(), v_v1, v_d1, 'over_consumption', 'medium', 'resolved',
   'Unusual Fuel Consumption',
   'RAE 001 A consumed 15% more fuel than expected on June 3 trip.',
   0.79, now() - interval '4 days'),

  (gen_random_uuid(), v_v4, v_d4, 'over_consumption', 'high', 'open',
   'Suspicious Fuel Usage — Executive Vehicle',
   'RAE 004 D consumed 55% more fuel than expected on its Nyarutarama–Convention Centre route this month.',
   0.91, now() - interval '8 hours');

-- ── 8. FUEL REQUESTS ─────────────────────────────────────────────────────────

INSERT INTO public.fuel_requests (
  id, vehicle_id, driver_id, requested_quantity_l, purpose, status,
  approved_by, approved_at, rejection_reason, unit_price_rwf, created_at
) VALUES
  (gen_random_uuid(), v_v1, v_d1, 60.0, 'Weekly refill — Musanze route',
   'pending', null, null, null, null, now() - interval '2 hours'),

  (gen_random_uuid(), v_v2, v_d2, 80.0, 'Weekly refill — Huye route',
   'pending', null, null, null, null, now() - interval '1 hour'),

  (gen_random_uuid(), v_v3, v_d3, 50.0, 'Refill — Rwamagana route',
   'approved', v_mgr, now() - interval '3 days', null, 1450.0,
   now() - interval '3 days 2 hours'),

  (gen_random_uuid(), v_v1, v_d1, 60.0, 'Refill — Musanze route',
   'approved', v_mgr, now() - interval '5 days', null, 1520.0,
   now() - interval '5 days 4 hours'),

  (gen_random_uuid(), v_v3, v_d3, 50.0, null,
   'rejected', null, null, 'Missing trip log for previous week', null,
   now() - interval '10 days'),

  (gen_random_uuid(), v_v4, v_d4, 70.0, 'Weekly refill — executive transport',
   'pending', null, null, null, null, now() - interval '30 minutes');

END $$;

-- ── 9. PHASE 1 EXTRA — VEHICLES + ROUTES + 6-MONTH HISTORY FOR DRIVER5-30 ────
-- Runs as its own transaction so a failure here never rolls back the core
-- accounts created above. Each driver gets a vehicle (cycled from 7 templates),
-- a 5-leg home→school→work→stop→work→home daily loop (locations from the
-- Kigali location list), one full route per working day (Mon-Fri) for Jan-May
-- 2026 plus June 1 through today, a per-driver consumption multiplier (driver8
-- tuned to "Suspicious", others spread across Efficient/Normal/High Consumption),
-- weekly fuel refills (capped at today), and June waypoints for the live map.
DO $$
DECLARE
  -- Coordinate lookup: name -> [lat, lng]
  loc CONSTANT jsonb := '{
    "Busanza": [-1.9897, 30.1300], "Masaka": [-1.9550, 30.1700],
    "Kanombe": [-1.9706, 30.1494], "Kicukiro": [-1.9650, 30.1000],
    "Gikondo": [-1.9783, 30.0719], "Kimironko": [-1.9417, 30.1147],
    "Kibagabaga": [-1.9217, 30.1127], "Nyarutarama": [-1.9379, 30.1027],
    "Nyamirambo": [-1.9783, 30.0386], "Kacyiru": [-1.9417, 30.0889],
    "Kimihurura": [-1.9499, 30.0926], "Gisozi": [-1.9219, 30.0589],
    "Remera": [-1.9577, 30.1127], "Gacuriro": [-1.9167, 30.0917],
    "Kabeza": [-1.9650, 30.1250], "Gatenga": [-1.9850, 30.1100],
    "Kagarama": [-1.9750, 30.1200], "Kicukiro Centre": [-1.9650, 30.1050],
    "Rebero": [-1.9950, 30.0950], "Niboye": [-1.9700, 30.1150],
    "NPD Kicukiro": [-1.9706, 30.1044],
    "Green Hills Academy": [-1.9300, 30.1200],
    "Mother Mary International School": [-1.9650, 30.1450],
    "Saint Ignatius School": [-1.9600, 30.1000],
    "Riviera High School": [-1.9450, 30.0950],
    "Kigali Parents School": [-1.9550, 30.0850],
    "Excella School": [-1.9400, 30.1050],
    "SOS School": [-1.9350, 30.0900],
    "Wellspring Academy": [-1.9250, 30.0850],
    "Lycée de Kigali": [-1.9500, 30.0600],
    "Kigali International Community School": [-1.9300, 30.1100]
  }'::jsonb;

  -- 7 vehicle templates, cycled across drivers 5..30
  v_templates CONSTANT jsonb := '[
    {"make":"Toyota","model":"Land Cruiser","type":"suv","fuel":"petrol","tank":90,"eff":8.0,"color":"White"},
    {"make":"Nissan","model":"Patrol","type":"suv","fuel":"diesel","tank":95,"eff":7.0,"color":"Black"},
    {"make":"Toyota","model":"Corolla","type":"sedan","fuel":"petrol","tank":50,"eff":13.0,"color":"Blue"},
    {"make":"Toyota","model":"RAV4","type":"suv","fuel":"petrol","tank":60,"eff":11.0,"color":"Grey"},
    {"make":"Isuzu","model":"NPR Truck","type":"truck","fuel":"diesel","tank":100,"eff":5.0,"color":"White"},
    {"make":"Toyota","model":"Coaster","type":"bus","fuel":"diesel","tank":95,"eff":6.0,"color":"White"},
    {"make":"Toyota","model":"Hilux","type":"pickup","fuel":"diesel","tank":80,"eff":9.0,"color":"Silver"}
  ]'::jsonb;

  homes CONSTANT text[] := ARRAY[
    'Busanza','Masaka','Kanombe','Kicukiro','Gikondo','Kimironko','Kibagabaga','Nyarutarama',
    'Nyamirambo','Kacyiru','Kimihurura','Gisozi','Remera','Gacuriro','Kabeza','Gatenga',
    'Kagarama','Kicukiro Centre','Rebero','Niboye'
  ];
  schools CONSTANT text[] := ARRAY[
    'Green Hills Academy','Mother Mary International School','Saint Ignatius School',
    'Riviera High School','Kigali Parents School','Excella School','SOS School',
    'Wellspring Academy','Lycée de Kigali','Kigali International Community School'
  ];

  s_min CONSTANT int[] := ARRAY[390,435,750,840,1050];
  s_legs CONSTANT int := 5;
  wp_steps CONSTANT int := 20;
  -- Cycled consumption multipliers -> spread across Efficient/Normal/High/Suspicious.
  -- Driver8 (i=4) is overridden below to be the spec's "Suspicious" example.
  mults CONSTANT numeric[] := ARRAY[0.65, 0.95, 1.10, 1.30, 0.85, 1.55];

  i int; d_id uuid; veh_id uuid; tmpl jsonb; home_name text; school_name text; stop_name text;
  plate text; s_eff numeric; mult numeric;
  s_from text[]; s_to text[]; s_olat numeric[]; s_olng numeric[]; s_dlat numeric[]; s_dlng numeric[]; s_dist numeric[];
  m int; leg int; factor numeric; fuel numeric; dur int;
  st timestamptz; en timestamptz; month_start date; month_end date; d date; daily_dist numeric;
  f_idx int; f_days CONSTANT int[] := ARRAY[1,8,15,22]; f_date date;
  unit_price numeric; qty numeric; odo_base numeric;
  trip_rec RECORD; wp_i int; wp_frac numeric;
BEGIN
  FOR i IN 1..26 LOOP
    d_id    := ('a1111111-0000-0000-0000-' || LPAD((i + 14)::text, 12, '0'))::uuid;
    veh_id  := ('b1111111-0000-0000-0000-' || LPAD((i + 4)::text, 12, '0'))::uuid;
    tmpl    := v_templates -> ((i - 1) % jsonb_array_length(v_templates));
    home_name   := homes[((i - 1) % array_length(homes, 1)) + 1];
    school_name := schools[((i - 1) % array_length(schools, 1)) + 1];
    stop_name   := homes[((i + 4) % array_length(homes, 1)) + 1];
    plate := 'RAE ' || LPAD((i + 4)::text, 3, '0') || ' ' || chr(65 + ((i - 1) % 26));
    s_eff := (tmpl->>'eff')::numeric;
    odo_base := 10000 + i * 1500;
    -- Driver8 (i=4) is the spec's "Suspicious" worked example; everyone else cycles
    -- through the mults array for an Efficient/Normal/High-Consumption spread.
    mult := CASE WHEN i = 4 THEN 1.80 ELSE mults[((i - 1) % array_length(mults, 1)) + 1] END;

    INSERT INTO public.vehicles (
      id, plate_number, make, model, year, vehicle_type, fuel_type,
      tank_capacity_l, current_fuel_l, odometer_km, status,
      assigned_driver_id, color
    ) VALUES (
      veh_id, plate, tmpl->>'make', tmpl->>'model', 2021 + (i % 4), tmpl->>'type', tmpl->>'fuel',
      (tmpl->>'tank')::numeric, (tmpl->>'tank')::numeric * 0.6, odo_base, 'active', d_id, tmpl->>'color'
    );

    -- Build the 5-leg daily loop: home -> school -> work -> stop -> work -> home
    s_from := ARRAY[home_name, school_name, 'NPD Kicukiro', stop_name, 'NPD Kicukiro'];
    s_to   := ARRAY[school_name, 'NPD Kicukiro', stop_name, 'NPD Kicukiro', home_name];
    FOR leg IN 1..s_legs LOOP
      s_olat[leg] := (loc -> s_from[leg] ->> 0)::numeric;
      s_olng[leg] := (loc -> s_from[leg] ->> 1)::numeric;
      s_dlat[leg] := (loc -> s_to[leg]   ->> 0)::numeric;
      s_dlng[leg] := (loc -> s_to[leg]   ->> 1)::numeric;
      s_dist[leg] := GREATEST(round(sqrt(
        power((s_dlat[leg] - s_olat[leg]) * 111, 2) +
        power((s_dlng[leg] - s_olng[leg]) * cos(radians(s_olat[leg])) * 111, 2)
      )::numeric, 1), 1.0);
    END LOOP;
    daily_dist := s_dist[1] + s_dist[2] + s_dist[3] + s_dist[4] + s_dist[5];

    -- Jan-Jun 2026 trip history: one full daily route per working day (Mon-Fri),
    -- June capped at today (CURRENT_DATE) since this month's data is "to date".
    FOR m IN 0..5 LOOP
      month_start := (date '2026-01-01' + (m::text || ' months')::interval)::date;
      month_end := LEAST((month_start + interval '1 month' - interval '1 day')::date, CURRENT_DATE);
      d := month_start;
      WHILE d <= month_end LOOP
        IF EXTRACT(ISODOW FROM d) <= 5 THEN
          FOR leg IN 1..s_legs LOOP
            factor := mult * (0.90 + ((EXTRACT(DOY FROM d)::int * 7 + leg * 3 + i) % 11) * 0.02);
            fuel := round((s_dist[leg] / s_eff) * factor, 2);
            dur  := GREATEST(round(s_dist[leg] / 40.0 * 60)::int, 5);
            st   := (d::text || ' ' || lpad((s_min[leg] / 60)::text, 2, '0') || ':' || lpad((s_min[leg] % 60)::text, 2, '0') || ':00+02')::timestamptz;
            en   := st + (dur::text || ' minutes')::interval;
            INSERT INTO public.gps_trips (
              id, vehicle_id, driver_id, status, origin_name, destination_name,
              origin_lat, origin_lng, destination_lat, destination_lng,
              distance_km, fuel_consumed_l, fuel_efficiency,
              started_at, ended_at, duration_minutes
            ) VALUES (
              gen_random_uuid(), veh_id, d_id, 'completed', s_from[leg], s_to[leg],
              s_olat[leg], s_olng[leg], s_dlat[leg], s_dlng[leg],
              s_dist[leg], fuel, s_eff, st, en, dur
            );
          END LOOP;
        END IF;
        d := d + 1;
      END LOOP;
    END LOOP;

    -- Weekly fuel refills, Jan-Jun 2026 (4/month)
    unit_price := CASE WHEN tmpl->>'fuel' = 'diesel' THEN 1450.0 ELSE 1520.0 END;
    qty := round((tmpl->>'tank')::numeric * 0.7, 1);
    FOR m IN 0..5 LOOP
      FOR f_idx IN 1..4 LOOP
        f_date := (date '2026-01-01' + (m::text || ' months')::interval)::date + (f_days[f_idx] - 1);
        CONTINUE WHEN f_date > CURRENT_DATE;
        INSERT INTO public.fuel_transactions (
          id, vehicle_id, driver_id, transaction_type,
          quantity_l, unit_price_rwf, total_cost_rwf,
          odometer_km, recorded_at, notes
        ) VALUES (
          gen_random_uuid(), veh_id, d_id, 'refill',
          qty, unit_price, qty * unit_price,
          odo_base + (m * 4 + (f_idx - 1)) * round(daily_dist * 6),
          (f_date::text || ' 12:00:00+02')::timestamptz,
          'Weekly refill — ' || home_name || '/' || (tmpl->>'model') || ' route'
        );
      END LOOP;
    END LOOP;

    -- June 2026 waypoints (21 per trip, for the live map)
    FOR trip_rec IN
      SELECT * FROM public.gps_trips
      WHERE vehicle_id = veh_id
        AND started_at >= '2026-06-01'::timestamptz
        AND started_at <  '2026-07-01'::timestamptz
    LOOP
      FOR wp_i IN 0..wp_steps LOOP
        wp_frac := wp_i::numeric / wp_steps;
        INSERT INTO public.trip_waypoints (
          id, trip_id, sequence_no, latitude, longitude,
          speed_kmh, fuel_level_l, recorded_at
        ) VALUES (
          gen_random_uuid(), trip_rec.id, wp_i,
          trip_rec.origin_lat + (trip_rec.destination_lat - trip_rec.origin_lat) * wp_frac,
          trip_rec.origin_lng + (trip_rec.destination_lng - trip_rec.origin_lng) * wp_frac,
          CASE WHEN wp_i = 0 OR wp_i = wp_steps THEN 0 ELSE 70.0 + (wp_i % 4) * 12.0 END,
          (tmpl->>'tank')::numeric * 0.6 - (trip_rec.fuel_consumed_l / wp_steps) * wp_i,
          trip_rec.started_at + (trip_rec.ended_at - trip_rec.started_at) * wp_frac
        );
      END LOOP;
    END LOOP;
  END LOOP;
END $$;

-- ── 10. ROW LEVEL SECURITY POLICIES ──────────────────────────────────────────
-- Grants each role the correct read/write access in the live backend.

-- Enable RLS on all tables
ALTER TABLE public.profiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gps_trips        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_requests    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_prices      ENABLE ROW LEVEL SECURITY;

-- Helper: get current user role from profiles
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- ── PROFILES ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_admin_all" ON public.profiles;

-- Any logged-in user reads own profile; admin + manager read all
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin')
  );

-- Users update own profile
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid());

-- Admin can insert / delete (for user management)
CREATE POLICY "profiles_admin_all" ON public.profiles
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('admin', 'super_admin'));

-- ── VEHICLES ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "vehicles_select" ON public.vehicles;
DROP POLICY IF EXISTS "vehicles_write" ON public.vehicles;

-- Drivers see only their assigned vehicle; admin/manager see all
CREATE POLICY "vehicles_select" ON public.vehicles
  FOR SELECT TO authenticated
  USING (
    assigned_driver_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin')
  );

-- Admin + manager can insert/update/delete vehicles
CREATE POLICY "vehicles_write" ON public.vehicles
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin'));

-- ── GPS TRIPS ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "trips_select" ON public.gps_trips;
DROP POLICY IF EXISTS "trips_insert" ON public.gps_trips;
DROP POLICY IF EXISTS "trips_admin_all" ON public.gps_trips;

-- Drivers see own trips; admin/manager see all
CREATE POLICY "trips_select" ON public.gps_trips
  FOR SELECT TO authenticated
  USING (
    driver_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin')
  );

-- Drivers insert own trips
CREATE POLICY "trips_insert" ON public.gps_trips
  FOR INSERT TO authenticated
  WITH CHECK (driver_id = auth.uid());

-- Admin/manager full control
CREATE POLICY "trips_admin_all" ON public.gps_trips
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin'));

-- ── FUEL TRANSACTIONS ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "transactions_select" ON public.fuel_transactions;
DROP POLICY IF EXISTS "transactions_write" ON public.fuel_transactions;

-- Drivers see own; admin/manager see all
CREATE POLICY "transactions_select" ON public.fuel_transactions
  FOR SELECT TO authenticated
  USING (
    driver_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin')
  );

-- Admin/manager insert/update/delete
CREATE POLICY "transactions_write" ON public.fuel_transactions
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin'));

-- ── FUEL REQUESTS ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "requests_select" ON public.fuel_requests;
DROP POLICY IF EXISTS "requests_driver_insert" ON public.fuel_requests;
DROP POLICY IF EXISTS "requests_admin_write" ON public.fuel_requests;

-- Drivers see own; admin/manager see all
CREATE POLICY "requests_select" ON public.fuel_requests
  FOR SELECT TO authenticated
  USING (
    driver_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin')
  );

-- Drivers submit their own requests
CREATE POLICY "requests_driver_insert" ON public.fuel_requests
  FOR INSERT TO authenticated
  WITH CHECK (driver_id = auth.uid());

-- Admin/manager approve/reject (UPDATE) and full control
CREATE POLICY "requests_admin_write" ON public.fuel_requests
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin'));

-- ── ALERTS ────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "alerts_select" ON public.alerts;
DROP POLICY IF EXISTS "alerts_driver_select" ON public.alerts;
DROP POLICY IF EXISTS "alerts_admin_write" ON public.alerts;

-- Drivers see alerts for their vehicle; admin/manager see all
CREATE POLICY "alerts_select" ON public.alerts
  FOR SELECT TO authenticated
  USING (
    driver_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin')
  );

-- Admin/manager insert/update/delete alerts
CREATE POLICY "alerts_admin_write" ON public.alerts
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin'));

-- ── FUEL PRICES ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "prices_select" ON public.fuel_prices;
DROP POLICY IF EXISTS "prices_write" ON public.fuel_prices;

-- All authenticated users read fuel prices
CREATE POLICY "prices_select" ON public.fuel_prices
  FOR SELECT TO authenticated
  USING (true);

-- Admin + manager set prices
CREATE POLICY "prices_write" ON public.fuel_prices
  FOR ALL TO authenticated
  USING (public.current_user_role() IN ('admin', 'fleet_manager', 'super_admin'));

-- ── NOTIFICATIONS ─────────────────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;

-- Each user sees their own notifications; admin/super_admin see every notification
CREATE POLICY "notifications_select" ON public.notifications
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'super_admin')
  );

-- Triggers (SECURITY DEFINER) and the app's own budget-threshold checks both
-- need to write notifications for users other than the caller (e.g. a driver
-- submitting a request creates a notification for the fleet manager).
CREATE POLICY "notifications_insert" ON public.notifications
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "notifications_update" ON public.notifications
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'super_admin')
  );

CREATE POLICY "notifications_delete" ON public.notifications
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'super_admin')
  );

-- ── NOTIFICATION TRIGGERS ─────────────────────────────────────────────────────

-- Fuel request submitted -> notify fleet managers / admins
CREATE OR REPLACE FUNCTION public.notify_fuel_request_submitted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_driver_name text;
  v_vehicle_label text;
  r RECORD;
BEGIN
  SELECT full_name INTO v_driver_name FROM public.profiles WHERE id = NEW.driver_id;
  SELECT COALESCE(make || ' ' || model, '') || ' (' || plate_number || ')'
    INTO v_vehicle_label FROM public.vehicles WHERE id = NEW.vehicle_id;

  FOR r IN SELECT id FROM public.profiles WHERE role IN ('fleet_manager', 'admin', 'super_admin') LOOP
    INSERT INTO public.notifications (user_id, title, message, type, category, priority, related_id)
    VALUES (
      r.id,
      'New Fuel Request Submitted',
      COALESCE(v_driver_name, 'A driver') || ' requested ' || NEW.requested_quantity_l ||
        ' L for ' || COALESCE(v_vehicle_label, 'their vehicle') ||
        COALESCE('. Purpose: ' || NEW.purpose, '') || '. Status: Pending Approval.',
      'fuel_request_submitted', 'fuel_request', 'medium', NEW.id
    );
  END LOOP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_fuel_request_submitted ON public.fuel_requests;
CREATE TRIGGER trg_notify_fuel_request_submitted
  AFTER INSERT ON public.fuel_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_fuel_request_submitted();

-- Fuel request approved/rejected -> notify the requesting driver
CREATE OR REPLACE FUNCTION public.notify_fuel_request_decision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_vehicle_label text;
  v_approver_name text;
BEGIN
  IF NEW.status = OLD.status THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(make || ' ' || model, '') || ' (' || plate_number || ')'
    INTO v_vehicle_label FROM public.vehicles WHERE id = NEW.vehicle_id;

  IF NEW.status = 'approved' THEN
    SELECT full_name INTO v_approver_name FROM public.profiles WHERE id = NEW.approved_by;
    INSERT INTO public.notifications (user_id, title, message, type, category, priority, related_id)
    VALUES (
      NEW.driver_id,
      'Fuel Request Approved',
      'Your fuel request for ' || COALESCE(v_vehicle_label, 'your vehicle') ||
        ' has been approved. Approved quantity: ' || NEW.requested_quantity_l || ' L.' ||
        COALESCE(' Approved by: ' || v_approver_name || '.', ''),
      'fuel_request_approved', 'fuel_request', 'medium', NEW.id
    );
  ELSIF NEW.status = 'rejected' THEN
    INSERT INTO public.notifications (user_id, title, message, type, category, priority, related_id)
    VALUES (
      NEW.driver_id,
      'Fuel Request Rejected',
      'Your fuel request for ' || COALESCE(v_vehicle_label, 'your vehicle') || ' has been rejected.' ||
        COALESCE(' Reason: ' || NEW.rejection_reason || '.', ''),
      'fuel_request_rejected', 'fuel_request', 'high', NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_fuel_request_decision ON public.fuel_requests;
CREATE TRIGGER trg_notify_fuel_request_decision
  AFTER UPDATE ON public.fuel_requests
  FOR EACH ROW EXECUTE FUNCTION public.notify_fuel_request_decision();

-- AI alert created -> notify the affected driver + fleet managers/admins
CREATE OR REPLACE FUNCTION public.notify_alert_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_priority text;
  v_type text;
  r RECORD;
BEGIN
  v_priority := CASE NEW.severity
    WHEN 'critical' THEN 'critical'
    WHEN 'high' THEN 'high'
    WHEN 'medium' THEN 'medium'
    ELSE 'low'
  END;
  v_type := CASE NEW.alert_type
    WHEN 'unusual_route' THEN 'route_deviation'
    WHEN 'over_consumption' THEN 'high_fuel_consumption'
    WHEN 'possible_theft' THEN 'suspicious_driver'
    WHEN 'low_fuel' THEN 'low_fuel'
    ELSE 'ai_alert'
  END;

  IF NEW.driver_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, message, type, category, priority, related_id)
    VALUES (
      NEW.driver_id,
      CASE WHEN v_type IN ('route_deviation', 'high_fuel_consumption', 'suspicious_driver')
           THEN 'Fuel Usage Alert' ELSE NEW.title END,
      COALESCE(NEW.description, NEW.title) ||
        CASE WHEN NEW.ai_confidence IS NOT NULL
             THEN ' Risk Score: ' || round(NEW.ai_confidence * 100) || '%.' ELSE '' END,
      v_type, 'ai_alert', v_priority, NEW.id
    );
  END IF;

  FOR r IN SELECT id FROM public.profiles WHERE role IN ('fleet_manager', 'admin', 'super_admin') LOOP
    INSERT INTO public.notifications (user_id, title, message, type, category, priority, related_id)
    VALUES (
      r.id,
      CASE WHEN v_type = 'suspicious_driver' THEN 'Suspicious Fuel Activity Detected' ELSE NEW.title END,
      COALESCE(NEW.description, NEW.title) ||
        CASE WHEN NEW.ai_confidence IS NOT NULL
             THEN ' Risk Score: ' || round(NEW.ai_confidence * 100) || '%.' ELSE '' END,
      v_type, 'ai_alert', v_priority, NEW.id
    );
  END LOOP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_alert_created ON public.alerts;
CREATE TRIGGER trg_notify_alert_created
  AFTER INSERT ON public.alerts
  FOR EACH ROW EXECUTE FUNCTION public.notify_alert_created();

-- Vehicle assigned/changed -> notify the driver
CREATE OR REPLACE FUNCTION public.notify_vehicle_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.assigned_driver_id IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.assigned_driver_id IS DISTINCT FROM OLD.assigned_driver_id) THEN
    INSERT INTO public.notifications (user_id, title, message, type, category, priority, related_id)
    VALUES (
      NEW.assigned_driver_id,
      CASE WHEN TG_OP = 'INSERT' THEN 'Vehicle Assigned' ELSE 'Vehicle Changed' END,
      'You have been assigned ' || NEW.make || ' ' || NEW.model || ' (' || NEW.plate_number || ').',
      CASE WHEN TG_OP = 'INSERT' THEN 'vehicle_assigned' ELSE 'vehicle_changed' END,
      'vehicle', 'medium', NEW.id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_vehicle_assignment ON public.vehicles;
CREATE TRIGGER trg_notify_vehicle_assignment
  AFTER INSERT OR UPDATE OF assigned_driver_id ON public.vehicles
  FOR EACH ROW EXECUTE FUNCTION public.notify_vehicle_assignment();

-- ── 11. RELOAD POSTGREST SCHEMA CACHE ────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
