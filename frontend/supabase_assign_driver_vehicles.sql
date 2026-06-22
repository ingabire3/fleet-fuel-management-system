-- ════════════════════════════════════════════════════════════════════════════
-- ASSIGN VEHICLES TO DRIVER5..DRIVER30 — run once against the LIVE Supabase project.
-- Idempotent / safe to re-run:
--   1. Creates the driver5..driver30@npd.rw test accounts (password
--      'npd2024drv') if they don't already exist.
--   2. For each of those drivers with NO vehicle assigned, reuses a free
--      vehicle or creates a new one (cycled from 7 templates) and assigns it.
-- Each new assignment fires trg_notify_vehicle_assignment, so the driver
-- gets a "Vehicle Assigned" notification in-app.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. ENSURE DRIVER5..DRIVER30 ACCOUNTS EXIST ───────────────────────────────
DO $$
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

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = d_email) THEN
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
    END IF;

    INSERT INTO public.profiles (id, full_name, phone, role, is_approved)
    VALUES (d_id, d_names[i], '+25078882' || LPAD((1000 + i)::text, 4, '0'), 'driver', true)
    ON CONFLICT (id) DO UPDATE SET
      full_name   = EXCLUDED.full_name,
      phone       = EXCLUDED.phone,
      role        = EXCLUDED.role,
      is_approved = EXCLUDED.is_approved;
  END LOOP;
END $$;

-- ── 2. ASSIGN A VEHICLE TO EACH DRIVER WITHOUT ONE ───────────────────────────
DO $$
DECLARE
  v_templates CONSTANT jsonb := '[
    {"make":"Toyota","model":"Land Cruiser","type":"suv","fuel":"petrol","tank":90,"eff":8.0,"color":"White"},
    {"make":"Nissan","model":"Patrol","type":"suv","fuel":"diesel","tank":95,"eff":7.0,"color":"Black"},
    {"make":"Toyota","model":"Corolla","type":"sedan","fuel":"petrol","tank":50,"eff":13.0,"color":"Blue"},
    {"make":"Toyota","model":"RAV4","type":"suv","fuel":"petrol","tank":60,"eff":11.0,"color":"Grey"},
    {"make":"Isuzu","model":"NPR Truck","type":"truck","fuel":"diesel","tank":100,"eff":5.0,"color":"White"},
    {"make":"Toyota","model":"Coaster","type":"bus","fuel":"diesel","tank":95,"eff":6.0,"color":"White"},
    {"make":"Toyota","model":"Hilux","type":"pickup","fuel":"diesel","tank":80,"eff":9.0,"color":"Silver"}
  ]'::jsonb;
  r RECORD;
  tmpl jsonb;
  free_vehicle uuid;
  new_plate text;
  i int := 0;
  p int;
BEGIN
  FOR r IN
    SELECT p.id, p.full_name, u.email
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE u.email ~ '^driver([5-9]|[12][0-9]|30)@npd\.rw$'
      AND NOT EXISTS (
        SELECT 1 FROM public.vehicles v WHERE v.assigned_driver_id = p.id
      )
    ORDER BY u.email
  LOOP
    i := i + 1;

    -- Reuse an existing unassigned vehicle first.
    SELECT id INTO free_vehicle
    FROM public.vehicles
    WHERE assigned_driver_id IS NULL
    ORDER BY plate_number
    LIMIT 1;

    IF free_vehicle IS NOT NULL THEN
      UPDATE public.vehicles SET assigned_driver_id = r.id WHERE id = free_vehicle;
    ELSE
      tmpl := v_templates -> ((i - 1) % jsonb_array_length(v_templates));

      -- Generate a unique RAF-series plate number.
      p := i;
      LOOP
        new_plate := 'RAF ' || LPAD(p::text, 3, '0') || ' ' || chr(65 + ((p - 1) % 26));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.vehicles WHERE plate_number = new_plate);
        p := p + 1;
      END LOOP;

      INSERT INTO public.vehicles (
        plate_number, make, model, year, vehicle_type, fuel_type,
        tank_capacity_l, current_fuel_l, odometer_km, status,
        assigned_driver_id, color
      ) VALUES (
        new_plate, tmpl->>'make', tmpl->>'model', 2021 + (i % 4),
        (tmpl->>'type')::vehicle_type, (tmpl->>'fuel')::fuel_type,
        (tmpl->>'tank')::numeric, (tmpl->>'tank')::numeric * 0.6, 10000 + i * 1500, 'active',
        r.id, tmpl->>'color'
      );
    END IF;

    RAISE NOTICE 'Assigned vehicle to % (%)', r.full_name, r.email;
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';
