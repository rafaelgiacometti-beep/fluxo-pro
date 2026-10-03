-- Medical R.G. v1. Execute uma vez no SQL Editor de um projeto Supabase novo.
-- Registos separados por auth.uid(); sem escrita direta pela API.
begin;

create table public.fluxo_products (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null check(length(trim(name)) between 1 and 160), sku text not null default '' check(length(sku)<=60),
 price_cents bigint not null check(price_cents between 0 and 100000000), cost_cents bigint not null check(cost_cents between 0 and 100000000),
 minimum integer not null default 5 check(minimum between 0 and 100000000), lead_days integer not null default 30 check(lead_days between 0 and 365),
 active boolean not null default true, created_at timestamptz not null default now()
);
create unique index fluxo_product_sku on public.fluxo_products(owner_id,sku) where sku<>'';
create index on public.fluxo_products(owner_id);
create table public.fluxo_customers (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null check(length(trim(name)) between 1 and 160), phone text not null default '' check(length(phone)<=60),
 note text not null default '' check(length(note)<=1000), active boolean not null default true, created_at timestamptz not null default now()
);
create index on public.fluxo_customers(owner_id);
create table public.fluxo_purchases (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 product_id uuid not null references public.fluxo_products(id), supplier text not null check(length(trim(supplier)) between 1 and 160),
 quantity integer not null check(quantity between 1 and 100000000), unit_cents bigint not null check(unit_cents between 0 and 100000000),
 received integer not null default 0 check(received>=0 and received<=quantity), ordered_at date not null, expected_at date not null check(expected_at>=ordered_at),
 status text not null default 'open' check(status in ('open','received','cancelled')), note text not null default '' check(length(note)<=1000),
 created_at timestamptz not null default now()
);
create index on public.fluxo_purchases(owner_id);
create table public.fluxo_sales (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 product_id uuid not null references public.fluxo_products(id), customer_id uuid not null references public.fluxo_customers(id),
 quantity integer not null check(quantity between 1 and 100000000), unit_cents bigint not null check(unit_cents between 0 and 100000000),
 ordered_at date not null, status text not null default 'pending' check(status in ('pending','delivered','cancelled')),
 delivered_at date, followup_at date, followup_done boolean not null default false,
 note text not null default '' check(length(note)<=1000), created_at timestamptz not null default now()
);
create index on public.fluxo_sales(owner_id);
create index on public.fluxo_sales(owner_id,product_id,status);
create table public.fluxo_movements (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 product_id uuid not null references public.fluxo_products(id), quantity integer not null check(quantity<>0),
 note text not null check(length(note) between 1 and 1000), created_at timestamptz not null default now()
);
create index on public.fluxo_movements(owner_id,product_id);
create table public.fluxo_payments (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('sale','purchase')), record_id uuid not null,
 amount_cents bigint not null check(amount_cents between 1 and 100000000), paid_at date not null,
 method text not null check(length(trim(method)) between 1 and 160), created_at timestamptz not null default now()
);
create index on public.fluxo_payments(owner_id,kind,record_id);
create table public.fluxo_settings (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 name text not null default 'Medical R.G.' check(length(trim(name)) between 1 and 160), reminder_days integer not null default 5 check(reminder_days between 0 and 30)
);
create table public.fluxo_requests (
 owner_id uuid not null references auth.users(id) on delete cascade, id uuid not null, created_at timestamptz not null default now(), primary key(owner_id,id)
);

-- Anon não tem acesso às tabelas nem às funções. Authenticated só pode ler as suas linhas.
do $$
declare t text;
begin
 foreach t in array array['fluxo_products','fluxo_customers','fluxo_purchases','fluxo_sales','fluxo_movements','fluxo_payments','fluxo_settings','fluxo_requests'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on table public.%I from anon, authenticated',t);
  execute format('grant select on table public.%I to authenticated',t);
  execute format('create policy owner_read on public.%I for select to authenticated using (owner_id = (select auth.uid()))',t);
 end loop;
end $$;

create function public.fluxo_snapshot() returns jsonb language plpgsql security invoker set search_path=public,pg_temp as $$
declare u uuid:=auth.uid(); result jsonb;
begin
 if u is null then raise exception 'Entre na sua conta.'; end if;
 select jsonb_build_object(
  'products',coalesce((select jsonb_agg(to_jsonb(x)-'owner_id' order by x.created_at,x.id) from fluxo_products x where owner_id=u),'[]'::jsonb),
  'customers',coalesce((select jsonb_agg(to_jsonb(x)-'owner_id' order by x.created_at,x.id) from fluxo_customers x where owner_id=u),'[]'::jsonb),
  'purchases',coalesce((select jsonb_agg(to_jsonb(x)-'owner_id' order by x.created_at,x.id) from fluxo_purchases x where owner_id=u),'[]'::jsonb),
  'sales',coalesce((select jsonb_agg(to_jsonb(x)-'owner_id' order by x.created_at,x.id) from fluxo_sales x where owner_id=u),'[]'::jsonb),
  'movements',coalesce((select jsonb_agg(to_jsonb(x)-'owner_id' order by x.created_at,x.id) from fluxo_movements x where owner_id=u),'[]'::jsonb),
  'payments',coalesce((select jsonb_agg(to_jsonb(x)-'owner_id' order by x.created_at,x.id) from fluxo_payments x where owner_id=u),'[]'::jsonb),
  'settings',coalesce((select to_jsonb(x)-'owner_id' from fluxo_settings x where owner_id=u),'{"name":"Medical R.G.","reminder_days":5}'::jsonb),
  'requests','[]'::jsonb
 ) into result;
 return result;
end $$;

create function public.fluxo_action(a jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 u uuid:=auth.uid(); p jsonb:=a->'payload'; k text:=a->>'kind'; rid uuid:=(a->>'request_id')::uuid;
 record uuid:=nullif(p->>'id','')::uuid; pid uuid:=nullif(p->>'product_id','')::uuid;
 cid uuid:=nullif(p->>'customer_id','')::uuid; q integer; val bigint; physical bigint; reserved bigint;
 paid bigint; total bigint; d date; sale fluxo_sales%rowtype; purchase fluxo_purchases%rowtype;
 product fluxo_products%rowtype; new_id uuid; local_today date := (now() at time zone 'Europe/Lisbon')::date;
begin
 if u is null then raise exception 'Entre na sua conta.'; end if;
 if rid is null or p is null then raise exception 'Pedido inválido.'; end if;
 -- Serializa todas as alterações da mesma conta; evita reservas/pagamentos concorrentes.
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 if exists(select 1 from fluxo_requests where owner_id=u and id=rid) then return fluxo_snapshot(); end if;
 if pid is not null then
  select * into product from fluxo_products where owner_id=u and id=pid;
  if not found then raise exception 'Produto não encontrado.'; end if;
 end if;
 case k
 when 'product' then
  if record is null then
   insert into fluxo_products(owner_id,name,sku,price_cents,cost_cents,minimum,lead_days,active)
   values(u,trim(p->>'name'),coalesce(trim(p->>'sku'),''),(p->>'price_cents')::bigint,(p->>'cost_cents')::bigint,(p->>'minimum')::integer,(p->>'lead_days')::integer,coalesce((p->>'active')::boolean,true)) returning id into new_id;
   q:=coalesce((p->>'initial')::integer,0);if q<0 or q>100000000 then raise exception 'Stock inicial inválido.'; end if;
   if q>0 then insert into fluxo_movements(owner_id,product_id,quantity,note) values(u,new_id,q,'Stock inicial'); end if;
  else
   update fluxo_products set name=trim(p->>'name'),sku=coalesce(trim(p->>'sku'),''),price_cents=(p->>'price_cents')::bigint,cost_cents=(p->>'cost_cents')::bigint,minimum=(p->>'minimum')::integer,lead_days=(p->>'lead_days')::integer,active=(p->>'active')::boolean where owner_id=u and id=record;
   if not found then raise exception 'Produto não encontrado.'; end if;
  end if;
 when 'customer' then
  if record is null then
   insert into fluxo_customers(owner_id,name,phone,note,active) values(u,trim(p->>'name'),coalesce(p->>'phone',''),coalesce(p->>'note',''),coalesce((p->>'active')::boolean,true));
  else
   update fluxo_customers set name=trim(p->>'name'),phone=coalesce(p->>'phone',''),note=coalesce(p->>'note',''),active=(p->>'active')::boolean where owner_id=u and id=record;
   if not found then raise exception 'Cliente não encontrado.'; end if;
  end if;
 when 'purchase' then
  if pid is null or not product.active then raise exception 'Selecione um produto ativo.'; end if;
  insert into fluxo_purchases(owner_id,product_id,supplier,quantity,unit_cents,ordered_at,expected_at,note)
  values(u,pid,trim(p->>'supplier'),(p->>'quantity')::integer,(p->>'unit_cents')::bigint,(p->>'ordered_at')::date,(p->>'expected_at')::date,coalesce(p->>'note',''));
 when 'receive' then
  select * into purchase from fluxo_purchases where owner_id=u and id=record;
  if not found then raise exception 'Encomenda não encontrada.'; end if;
  q:=(p->>'quantity')::integer;
  if q is null or q<=0 or q>purchase.quantity-purchase.received or purchase.status<>'open' then raise exception 'Quantidade inválida ou encomenda encerrada.'; end if;
  update fluxo_purchases set received=received+q,status=case when received+q=quantity then 'received' else 'open' end where id=record and owner_id=u;
  insert into fluxo_movements(owner_id,product_id,quantity,note) values(u,purchase.product_id,q,'Receção: '||purchase.supplier);
 when 'sale' then
  if pid is null or not product.active then raise exception 'Selecione um produto ativo.'; end if;
  if not exists(select 1 from fluxo_customers where owner_id=u and id=cid and active) then raise exception 'Cliente não encontrado ou arquivado.'; end if;
  q:=(p->>'quantity')::integer;
  if q is null or q<=0 or q>100000000 then raise exception 'Quantidade inválida.'; end if;
  select coalesce(sum(quantity),0) into physical from fluxo_movements where owner_id=u and product_id=pid;
  select coalesce(sum(quantity),0) into reserved from fluxo_sales where owner_id=u and product_id=pid and status='pending';
  if physical-reserved<q and not coalesce((p->>'allow_backorder')::boolean,false) then raise exception 'Stock disponível insuficiente. Assinale pré-encomenda para aguardar a chegada.'; end if;
  insert into fluxo_sales(owner_id,product_id,customer_id,quantity,unit_cents,ordered_at,note)
  values(u,pid,cid,q,(p->>'unit_cents')::bigint,(p->>'ordered_at')::date,coalesce(p->>'note',''));
 when 'deliver' then
  select * into sale from fluxo_sales where owner_id=u and id=record;
  if not found or sale.status<>'pending' then raise exception 'Venda não encontrada ou já encerrada.'; end if;
  d:=(p->>'delivered_at')::date;
  if d is null or d<sale.ordered_at or d>local_today then raise exception 'A entrega deve ser entre a encomenda e hoje.'; end if;
  select coalesce(sum(quantity),0) into physical from fluxo_movements where owner_id=u and product_id=sale.product_id;
  if physical<sale.quantity then raise exception 'Stock insuficiente para entregar.'; end if;
  update fluxo_sales set status='delivered',delivered_at=d,followup_at=(d+interval '1 month')::date where id=record and owner_id=u;
  insert into fluxo_movements(owner_id,product_id,quantity,note) values(u,sale.product_id,-sale.quantity,'Entrega ao cliente');
 when 'payment' then
  record:=(p->>'record_id')::uuid;val:=(p->>'amount_cents')::bigint;d:=(p->>'paid_at')::date;
  if val is null or val<=0 or val>100000000 or d is null or d>local_today then raise exception 'Valor ou data do pagamento inválidos.'; end if;
  if p->>'kind'='sale' then
   select * into sale from fluxo_sales where owner_id=u and id=record;
   if not found or sale.status='cancelled' then raise exception 'Venda não encontrada ou cancelada.'; end if;
   total:=sale.quantity::bigint*sale.unit_cents;
  elsif p->>'kind'='purchase' then
   select * into purchase from fluxo_purchases where owner_id=u and id=record;
   if not found or purchase.status='cancelled' then raise exception 'Encomenda não encontrada ou cancelada.'; end if;
   total:=purchase.quantity::bigint*purchase.unit_cents;
  else raise exception 'Tipo de pagamento inválido.'; end if;
  select coalesce(sum(amount_cents),0) into paid from fluxo_payments where owner_id=u and record_id=record and kind=p->>'kind';
  if val>total-paid then raise exception 'O pagamento excede o valor em falta.'; end if;
  insert into fluxo_payments(owner_id,kind,record_id,amount_cents,paid_at,method) values(u,p->>'kind',record,val,d,trim(p->>'method'));
 when 'cancel' then
  select coalesce(sum(amount_cents),0) into paid from fluxo_payments where owner_id=u and record_id=record and kind=p->>'kind';
  if paid>0 then raise exception 'Não pode cancelar um registo com pagamentos.'; end if;
  if p->>'kind'='sale' then
   update fluxo_sales set status='cancelled' where id=record and owner_id=u and status='pending';
   if not found then raise exception 'Só pode cancelar uma venda por entregar.'; end if;
  elsif p->>'kind'='purchase' then
   update fluxo_purchases set status='cancelled' where id=record and owner_id=u and status='open' and received=0;
   if not found then raise exception 'Só pode cancelar encomendas sem receções.'; end if;
  else raise exception 'Tipo de registo inválido.'; end if;
 when 'adjust' then
  if pid is null then raise exception 'Produto não encontrado.'; end if;
  q:=(p->>'quantity')::integer;
  if q is null or q=0 or abs(q::bigint)>100000000 then raise exception 'Ajuste inválido.'; end if;
  select coalesce(sum(quantity),0) into physical from fluxo_movements where owner_id=u and product_id=pid;
  select coalesce(sum(quantity),0) into reserved from fluxo_sales where owner_id=u and product_id=pid and status='pending';
  if q<0 and physical+q-reserved<0 then raise exception 'O ajuste compromete stock reservado.'; end if;
  insert into fluxo_movements(owner_id,product_id,quantity,note) values(u,pid,q,trim(p->>'note'));
 when 'followup' then
  update fluxo_sales set followup_done=(p->>'done')::boolean where owner_id=u and id=record and status='delivered';
  if not found then raise exception 'Venda ainda não entregue.'; end if;
 when 'settings' then
  insert into fluxo_settings(owner_id,name,reminder_days) values(u,trim(p->>'name'),(p->>'reminder_days')::integer)
  on conflict(owner_id) do update set name=excluded.name,reminder_days=excluded.reminder_days;
 else raise exception 'Ação desconhecida.';
 end case;
 insert into fluxo_requests(owner_id,id) values(u,rid);
 return fluxo_snapshot();
end $$;

revoke all on function public.fluxo_snapshot() from public,anon;
revoke all on function public.fluxo_action(jsonb) from public,anon;
grant execute on function public.fluxo_snapshot() to authenticated;
grant execute on function public.fluxo_action(jsonb) to authenticated;
commit;
