do $migration$
declare
  v_expression text;
begin
  select pg_get_expr(polwithcheck, polrelid)
    into v_expression
  from pg_policy
  where polrelid = 'public.conversations'::regclass
    and polname = 'conversations_customer_create';
  if v_expression is not null then
    v_expression := replace(v_expression, 'auth.uid()', '(select auth.uid())');
    execute format(
      'alter policy conversations_customer_create on public.conversations with check (%s)',
      v_expression
    );
  end if;

  select pg_get_expr(polqual, polrelid)
    into v_expression
  from pg_policy
  where polrelid = 'public.feed_follows'::regclass
    and polname = 'feed_follows_delete';
  if v_expression is not null then
    v_expression := replace(v_expression, 'auth.uid()', '(select auth.uid())');
    execute format(
      'alter policy feed_follows_delete on public.feed_follows using (%s)',
      v_expression
    );
  end if;
end;
$migration$;
