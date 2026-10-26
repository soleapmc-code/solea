-- SOLEA + Supabase: ejecutar completo en SQL Editor del proyecto.
-- Publica únicamente la ficha del producto; las cantidades quedan en una tabla privada.
create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('Tacones','Sandalias','Flats','Sneakers','Botines')),
  price numeric(10,2) not null check (price >= 0),
  color text,
  tag text,
  description text,
  image_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  size text not null check (size in ('22','22.5','23','23.5','24','24.5','25','25.5','26','26.5','27')),
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  unique(product_id, size)
);

alter table public.products enable row level security;
alter table public.inventory enable row level security;

-- Limitar privilegios explícitamente. Los visitantes solo pueden leer productos activos.
revoke all on public.products from anon, authenticated;
revoke all on public.inventory from anon, authenticated;
grant select on public.products to anon, authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.inventory to authenticated;

drop policy if exists "Public can view active products" on public.products;
create policy "Public can view active products" on public.products
for select to anon, authenticated using (active = true);

drop policy if exists "Signed-in admins can read all products" on public.products;
create policy "Signed-in admins can read all products" on public.products
for select to authenticated using (true);

drop policy if exists "Signed-in users can insert products" on public.products;
create policy "Signed-in users can insert products" on public.products
for insert to authenticated with check (auth.uid() is not null);

drop policy if exists "Signed-in users can update products" on public.products;
create policy "Signed-in users can update products" on public.products
for update to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);

drop policy if exists "Signed-in users can delete products" on public.products;
create policy "Signed-in users can delete products" on public.products
for delete to authenticated using (auth.uid() is not null);

-- No se concede SELECT a anon en inventory ni existe política pública para esa tabla.
drop policy if exists "Signed-in users can read inventory" on public.inventory;
create policy "Signed-in users can read inventory" on public.inventory
for select to authenticated using (auth.uid() is not null);
drop policy if exists "Signed-in users can insert inventory" on public.inventory;
create policy "Signed-in users can insert inventory" on public.inventory
for insert to authenticated with check (auth.uid() is not null);
drop policy if exists "Signed-in users can update inventory" on public.inventory;
create policy "Signed-in users can update inventory" on public.inventory
for update to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
drop policy if exists "Signed-in users can delete inventory" on public.inventory;
create policy "Signed-in users can delete inventory" on public.inventory
for delete to authenticated using (auth.uid() is not null);

-- No se insertan productos de demostración automáticamente: carga tus productos reales desde el panel.

-- Supabase Storage para fotografías de productos. Bucket público solo para lectura de imágenes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('solea-productos', 'solea-productos', true, 5242880, array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg','image/png','image/webp','image/avif'];

-- Cualquier visitante puede ver las fotografías del catálogo; solo usuarios autenticados pueden subir, sustituir o borrar archivos.
drop policy if exists "Public can view SOLEA product photos" on storage.objects;
create policy "Public can view SOLEA product photos" on storage.objects
for select to public using (bucket_id = 'solea-productos');

drop policy if exists "Authenticated users can upload SOLEA product photos" on storage.objects;
create policy "Authenticated users can upload SOLEA product photos" on storage.objects
for insert to authenticated with check (bucket_id = 'solea-productos' and auth.uid() is not null);

drop policy if exists "Authenticated users can update SOLEA product photos" on storage.objects;
create policy "Authenticated users can update SOLEA product photos" on storage.objects
for update to authenticated using (bucket_id = 'solea-productos' and auth.uid() is not null) with check (bucket_id = 'solea-productos' and auth.uid() is not null);

drop policy if exists "Authenticated users can delete SOLEA product photos" on storage.objects;
create policy "Authenticated users can delete SOLEA product photos" on storage.objects
for delete to authenticated using (bucket_id = 'solea-productos' and auth.uid() is not null);
