create or replace function public.mayhem_jsonb_has_private_note_key(value jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  item record;
begin
  if jsonb_typeof(value) = 'object' then
    for item in
      select entry.key, entry.value
      from jsonb_each(value) as entry(key, value)
    loop
      if lower(replace(item.key, '_', '')) in (
        'note', 'notebody', 'privatenote', 'privatenotebody'
      ) or public.mayhem_jsonb_has_private_note_key(item.value) then
        return true;
      end if;
    end loop;
  elsif jsonb_typeof(value) = 'array' then
    for item in
      select null::text as key, array_item.element as value
      from jsonb_array_elements(value) as array_item(element)
    loop
      if public.mayhem_jsonb_has_private_note_key(item.value) then
        return true;
      end if;
    end loop;
  end if;
  return false;
end;
$$;
