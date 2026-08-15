-- =====================================================================
-- Snapshot query — run this TWICE: once BEFORE running schema.sql,
-- once AFTER. Copy both results somewhere (a text file, a second
-- browser tab, etc.) and compare — identical output means schema.sql
-- genuinely changed nothing on a database that already had everything.
--
-- Run this on portal-new's SQL Editor.
-- =====================================================================

select 'TABLE: ' || table_name as snapshot
from information_schema.tables
where table_schema = 'public'

union all

select 'COLUMN: ' || table_name || '.' || column_name
from information_schema.columns
where table_schema = 'public'

union all

select 'POLICY: ' || schemaname || '.' || tablename || '.' || policyname
from pg_policies
where schemaname in ('public', 'storage')

union all

select 'FUNCTION: ' || routine_name
from information_schema.routines
where routine_schema = 'public'

union all

select 'BUCKET: ' || id
from storage.buckets

order by 1;
