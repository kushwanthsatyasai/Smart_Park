-- Function to handle expired bookings
create or replace function handle_expired_booking(booking_id uuid, slot_id uuid)
returns void
language plpgsql
security definer
as $$
begin
  -- Update booking status to expired
  update parking_bookings
  set 
    status = 'expired',
    updated_at = now()
  where id = booking_id;

  -- Free up the parking slot
  update parking_slots
  set 
    is_available = true,
    updated_at = now()
  where id = slot_id;
end;
$$; 