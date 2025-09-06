-- Add new columns to the profiles table
ALTER TABLE public.profiles
ADD COLUMN first_name TEXT,
ADD COLUMN last_name TEXT,
ADD COLUMN mobile_number TEXT,
ADD COLUMN id_type TEXT,
ADD COLUMN id_value TEXT;

-- Update the handle_new_user function to include new profile fields
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, role, first_name, last_name, mobile_number, id_type, id_value)
  VALUES (NEW.id, NEW.email, 'user', NULL, NULL, NULL, NULL, NULL); -- Set new fields to NULL initially
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- You might want to update RLS policies if you want users to update these new fields for themselves.
-- For example, to allow users to update their new profile fields:
ALTER POLICY "Users can update their own profile." ON public.profiles
  WITH CHECK (auth.uid() = id);