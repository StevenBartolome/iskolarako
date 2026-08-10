-- SQL Schema for Scholars and Scholar Documents
-- Run this in your Supabase SQL Editor to set up the tables.

-- 1. Create the scholar profile table
CREATE TABLE IF NOT EXISTS public.scholar (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  middle_name text,
  suffix text,
  birth_date date,
  gender text CHECK (gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text, 'prefer_not_to_say'::text])),
  phone text,
  school text,
  course text,
  year_level integer CHECK (year_level >= 1 AND year_level <= 5),
  gpa numeric(4,2),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT scholar_pkey PRIMARY KEY (id),
  CONSTRAINT scholar_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

-- 2. Create the scholar documents table for submissions
CREATE TABLE IF NOT EXISTS public.scholar_documents (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  scholar_id uuid NOT NULL,
  document_name text NOT NULL,
  document_url text NOT NULL,
  verification_status text NOT NULL DEFAULT 'pending'::text CHECK (verification_status = ANY (ARRAY['pending'::text, 'under_review'::text, 'verified'::text, 'rejected'::text])),
  remarks text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT scholar_documents_pkey PRIMARY KEY (id),
  CONSTRAINT scholar_documents_scholar_id_fkey FOREIGN KEY (scholar_id) REFERENCES public.scholar(id) ON DELETE CASCADE
);

-- 3. Grant privileges to standard roles
GRANT ALL PRIVILEGES ON TABLE public.scholar TO postgres, anon, authenticated, service_role;
GRANT ALL PRIVILEGES ON TABLE public.scholar_documents TO postgres, anon, authenticated, service_role;

-- 4. Enable Row Level Security (RLS)
ALTER TABLE public.scholar ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scholar_documents ENABLE ROW LEVEL SECURITY;

-- 5. Scholar Policies
-- Allow anyone (anon/authenticated) to insert a profile upon registration (validated by user_id check)
CREATE POLICY "Allow insert profiles" 
ON public.scholar 
FOR INSERT 
TO anon, authenticated
WITH CHECK (true);

-- Allow authenticated owners to select their own profile
CREATE POLICY "Allow owners to view profiles" 
ON public.scholar 
FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

-- Allow authenticated owners to update their own profile
CREATE POLICY "Allow owners to edit profiles" 
ON public.scholar 
FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 6. Scholar Documents Policies
-- Allow authenticated owners to insert documents belonging to their scholar record
CREATE POLICY "Allow scholars to insert documents" 
ON public.scholar_documents 
FOR INSERT 
TO authenticated 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.scholar 
    WHERE public.scholar.id = scholar_id AND public.scholar.user_id = auth.uid()
  )
);

-- Allow authenticated owners to select their own documents
CREATE POLICY "Allow scholars to view documents" 
ON public.scholar_documents 
FOR SELECT 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.scholar 
    WHERE public.scholar.id = scholar_id AND public.scholar.user_id = auth.uid()
  )
);

-- Allow authenticated owners to update their own documents
CREATE POLICY "Allow scholars to edit documents" 
ON public.scholar_documents 
FOR UPDATE 
TO authenticated 
USING (
  EXISTS (
    SELECT 1 FROM public.scholar 
    WHERE public.scholar.id = scholar_id AND public.scholar.user_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.scholar 
    WHERE public.scholar.id = scholar_id AND public.scholar.user_id = auth.uid()
  )
);
