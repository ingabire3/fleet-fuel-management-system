-- ════════════════════════════════════════════════════════════════════════════
-- NOTIFICATION CENTER SETUP — run once against the LIVE Supabase project.
-- Safe to re-run (everything is idempotent / IF NOT EXISTS / CREATE OR REPLACE).
-- Unlike supabase_seed.sql, this script does NOT delete or reset any data.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. SUPER ADMIN ROLE + BUDGET COLUMN ───────────────────────────────────────
-- Must COMMIT before the new enum value is referenced later in this script.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS monthly_budget_rwf numeric NOT NULL DEFAULT 400000;

ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'super_admin';
COMMIT;

-- ── 2. NOTIFICATIONS TABLE ────────────────────────────────────────────────────
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

-- ── 3. HELPER: CURRENT USER ROLE (used by RLS policies below) ────────────────
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- ── 4. RLS POLICIES ────────────────────────────────────────────────────────────
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;

CREATE POLICY "notifications_select" ON public.notifications
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.current_user_role() IN ('admin', 'super_admin')
  );

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

-- ── 5. TRIGGERS ────────────────────────────────────────────────────────────────

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

-- ── 6. RELOAD POSTGREST SCHEMA CACHE ─────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
