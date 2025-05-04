-- Function to migrate vehicle data from profiles to user_vehicles
create or replace function migrate_vehicles()
returns void
language plpgsql
security definer
as $$
declare
  profile_record record;
begin
  -- Loop through all profiles that have vehicle data
  for profile_record in
    select id, vehicle_type, vehicle_number
    from profiles
    where vehicle_type is not null 
    and vehicle_number is not null
    and vehicle_type != 'cycle'
  loop
    -- Check if vehicle already exists in user_vehicles
    if not exists (
      select 1 from user_vehicles 
      where user_id = profile_record.id 
      and vehicle_number = profile_record.vehicle_number
    ) then
      -- Insert vehicle into user_vehicles
      insert into user_vehicles (
        user_id,
        vehicle_type,
        vehicle_number,
        nickname,
        created_at,
        updated_at
      ) values (
        profile_record.id,
        profile_record.vehicle_type,
        profile_record.vehicle_number,
        'My ' || initcap(profile_record.vehicle_type),
        now(),
        now()
      );
    end if;
  end loop;
end;
$$; 