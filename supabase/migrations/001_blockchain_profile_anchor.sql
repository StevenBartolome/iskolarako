-- ============================================================================
-- IskoAko: Blockchain Profile Anchoring Migration
-- Run this in your Supabase Dashboard → SQL Editor
-- ============================================================================

-- 1. Add blockchain anchor columns to scholar table
ALTER TABLE public.scholar
  ADD COLUMN IF NOT EXISTS profile_blockchain_tx_hash text,
  ADD COLUMN IF NOT EXISTS profile_blockchain_block bigint,
  ADD COLUMN IF NOT EXISTS profile_blockchain_hash text,
  ADD COLUMN IF NOT EXISTS profile_blockchain_verified boolean NOT NULL DEFAULT false;

-- 2. Create trigger function to protect face_verification_status
CREATE OR REPLACE FUNCTION protect_face_verification_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Handle INSERT: Prevent creating new account directly with verified status unless service_role
  IF TG_OP = 'INSERT' THEN
    IF NEW.face_verification_status = 'verified' THEN
      IF current_setting('role', true) IS DISTINCT FROM 'service_role' THEN
        RAISE EXCEPTION 'UNAUTHORIZED: New accounts cannot be registered with verified face status. Face verification must be completed in the app.';
      END IF;
    END IF;
    RETURN NEW;
  END IF;

  -- Handle UPDATE: Only fire if face_verification_status actually changed
  IF OLD.face_verification_status IS DISTINCT FROM NEW.face_verification_status THEN

    -- Log every change attempt to audit_logs
    BEGIN
      INSERT INTO public.audit_logs (actor, action, target, ip_address)
      VALUES (
        COALESCE(
          (current_setting('request.jwt.claims', true)::json->>'email'),
          'direct_db_access'
        ),
        'FACE_VERIFICATION_STATUS_CHANGED',
        format('scholar_id=%s | %s → %s', OLD.id, COALESCE(OLD.face_verification_status, 'NULL'), NEW.face_verification_status),
        COALESCE(
          (current_setting('request.headers', true)::json->>'x-forwarded-for'),
          'unknown'
        )
      );
    EXCEPTION WHEN OTHERS THEN
      -- Don't block the update if audit logging fails
      RAISE WARNING 'Audit log insert failed: %', SQLERRM;
    END;

    -- If changing TO 'verified', allow service_role (Edge Function) OR authenticated user updating their own profile
    IF NEW.face_verification_status = 'verified' THEN
      IF current_setting('role', true) IS DISTINCT FROM 'service_role' 
         AND auth.uid() IS DISTINCT FROM NEW.user_id THEN
        RAISE EXCEPTION 'UNAUTHORIZED: face_verification_status can only be set to verified through the face verification system.';
      END IF;
    END IF;

    -- Invalidate blockchain verification if status was changed after anchoring
    IF OLD.profile_blockchain_verified = true THEN
      NEW.profile_blockchain_verified := false;
      NEW.profile_blockchain_tx_hash := NULL;
      NEW.profile_blockchain_block := NULL;
      NEW.profile_blockchain_hash := NULL;
    END IF;

  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Drop existing trigger if it exists (safe re-run)
DROP TRIGGER IF EXISTS trg_protect_face_verification ON public.scholar;

-- 4. Attach trigger
CREATE TRIGGER trg_protect_face_verification
  BEFORE INSERT OR UPDATE ON public.scholar
  FOR EACH ROW
  EXECUTE FUNCTION protect_face_verification_status();

-- 5. Add comment for documentation
COMMENT ON TRIGGER trg_protect_face_verification ON public.scholar IS 
  'Prevents unauthorized changes to face_verification_status. Only service_role can set it to verified. Logs all changes to audit_logs. Invalidates blockchain anchor if status is changed after anchoring.';
