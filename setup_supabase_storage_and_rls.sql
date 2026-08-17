-- =====================================================================
-- IskoAko - Fix 42501 Permission Denied for scholar_payment_accounts & fund_releases
-- Run this script in Supabase Dashboard -> SQL Editor -> Run
-- =====================================================================

-- 1. Grant base PostgreSQL permissions to authenticated and anon roles
GRANT ALL ON TABLE public.scholar_payment_accounts TO authenticated, anon, service_role;
GRANT ALL ON TABLE public.fund_releases TO authenticated, anon, service_role;
GRANT ALL ON TABLE public.scholarship_programs TO authenticated, anon, service_role;

-- Grant sequence permissions
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon, service_role;

-- 2. Configure Row Level Security (RLS) for scholar_payment_accounts
ALTER TABLE public.scholar_payment_accounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select scholar_payment_accounts" ON public.scholar_payment_accounts;
DROP POLICY IF EXISTS "Allow insert scholar_payment_accounts" ON public.scholar_payment_accounts;
DROP POLICY IF EXISTS "Allow update scholar_payment_accounts" ON public.scholar_payment_accounts;
DROP POLICY IF EXISTS "Allow all for authenticated users on scholar_payment_accounts" ON public.scholar_payment_accounts;

CREATE POLICY "Allow select scholar_payment_accounts"
ON public.scholar_payment_accounts FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Allow insert scholar_payment_accounts"
ON public.scholar_payment_accounts FOR INSERT
TO authenticated, anon
WITH CHECK (true);

CREATE POLICY "Allow update scholar_payment_accounts"
ON public.scholar_payment_accounts FOR UPDATE
TO authenticated, anon
USING (true)
WITH CHECK (true);


-- 3. Configure Row Level Security (RLS) for fund_releases
ALTER TABLE public.fund_releases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select fund_releases" ON public.fund_releases;
DROP POLICY IF EXISTS "Allow insert fund_releases" ON public.fund_releases;
DROP POLICY IF EXISTS "Allow update fund_releases" ON public.fund_releases;
DROP POLICY IF EXISTS "Allow all for authenticated users on fund_releases" ON public.fund_releases;

CREATE POLICY "Allow select fund_releases"
ON public.fund_releases FOR SELECT
TO authenticated, anon
USING (true);

CREATE POLICY "Allow insert fund_releases"
ON public.fund_releases FOR INSERT
TO authenticated, anon
WITH CHECK (true);

CREATE POLICY "Allow update fund_releases"
ON public.fund_releases FOR UPDATE
TO authenticated, anon
USING (true)
WITH CHECK (true);


-- 4. Storage Bucket 'bank-proofs' setup and permissions
INSERT INTO storage.buckets (id, name, public)
VALUES ('bank-proofs', 'bank-proofs', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public Access bank-proofs" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Upload bank-proofs" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Update bank-proofs" ON storage.objects;

CREATE POLICY "Public Access bank-proofs"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'bank-proofs');

CREATE POLICY "Authenticated Upload bank-proofs"
ON storage.objects FOR INSERT
TO authenticated, anon
WITH CHECK (bucket_id = 'bank-proofs');

CREATE POLICY "Authenticated Update bank-proofs"
ON storage.objects FOR UPDATE
TO authenticated, anon
USING (bucket_id = 'bank-proofs');


-- 5. AI Document Verification Columns for scholar_documents
ALTER TABLE public.scholar_documents 
ADD COLUMN IF NOT EXISTS ai_verification_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS ai_confidence_score NUMERIC DEFAULT NULL,
ADD COLUMN IF NOT EXISTS ai_flags JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS ai_extracted_data JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS ai_model_used TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS file_sha256_hash TEXT DEFAULT NULL;

GRANT ALL ON TABLE public.scholar_documents TO authenticated, anon, service_role;

