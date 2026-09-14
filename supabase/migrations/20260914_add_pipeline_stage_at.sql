-- Records when a customer last entered its current pipeline stage; pipeline columns sort newest-first on it.
alter table public.customers add column if not exists pipeline_stage_at timestamptz;
create or replace function public.set_pipeline_stage_at() returns trigger language plpgsql as $$
begin
  if new.pipeline_stage is distinct from old.pipeline_stage then new.pipeline_stage_at := now(); end if;
  return new;
end $$;
drop trigger if exists trg_pipeline_stage_at on public.customers;
create trigger trg_pipeline_stage_at before update on public.customers for each row execute function public.set_pipeline_stage_at();
create or replace function public.set_pipeline_stage_at_insert() returns trigger language plpgsql as $$
begin
  if new.pipeline_stage is not null then new.pipeline_stage_at := now(); end if;
  return new;
end $$;
drop trigger if exists trg_pipeline_stage_at_ins on public.customers;
create trigger trg_pipeline_stage_at_ins before insert on public.customers for each row execute function public.set_pipeline_stage_at_insert();
create index if not exists customers_pipeline_stage_at_idx on public.customers (pipeline_stage_at desc);
