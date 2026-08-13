-- ============================================================
-- ISKOAKO SUPABASE STORAGE & RLS POLICY SETUP SCRIPT
-- Copy and run this script in your Supabase SQL Editor
-- ============================================================

-- 1. Create the Storage Bucket for Scholar Documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'scholar-documents',
  'scholar-documents',
  true,
  10485760, -- 10MB limit
  ARRAY['application/pdf', 'image/jpeg', 'image/png', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Storage Objects Access Policies (Allow Public Read & Authenticated Uploads)
DROP POLICY IF EXISTS "Public Scholar Documents Read" ON storage.objects;
CREATE POLICY "Public Scholar Documents Read"
ON storage.objects FOR SELECT
USING (bucket_id = 'scholar-documents');

DROP POLICY IF EXISTS "Authenticated Scholar Upload" ON storage.objects;
CREATE POLICY "Authenticated Scholar Upload"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'scholar-documents');

DROP POLICY IF EXISTS "Authenticated Scholar Update" ON storage.objects;
CREATE POLICY "Authenticated Scholar Update"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'scholar-documents');

-- 3. Row-Level Security (RLS) Policy for scholarship_applications Table
ALTER TABLE public.scholarship_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow scholar insert applications" ON public.scholarship_applications;
CREATE POLICY "Allow scholar insert applications"
ON public.scholarship_applications
FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow scholar select applications" ON public.scholarship_applications;
CREATE POLICY "Allow scholar select applications"
ON public.scholarship_applications
FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Allow scholar update applications" ON public.scholarship_applications;
CREATE POLICY "Allow scholar update applications"
ON public.scholarship_applications
FOR UPDATE
TO authenticated
USING (true);

-- 4. Enable RLS access for scholar_documents table
ALTER TABLE public.scholar_documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow scholar insert scholar_documents" ON public.scholar_documents;
CREATE POLICY "Allow scholar insert scholar_documents"
ON public.scholar_documents
FOR INSERT
TO authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow scholar select scholar_documents" ON public.scholar_documents;
CREATE POLICY "Allow scholar select scholar_documents"
ON public.scholar_documents
FOR SELECT
TO authenticated
USING (true);
